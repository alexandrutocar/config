{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.radii;

  # Derivation, device tunnels and checks, shared with the flake check.
  radii = import ./_module/lib {inherit lib;};

  # The peers this host has tunnels to; none while it is missing from the
  # site table, which an assertion reports.
  peers =
    if cfg.settings.site ? ${cfg.settings.self}
    then cfg.derived.peers
    else {};

  # Unit names in systemd.network.{netdevs,networks}, one per tunnel.
  unitOf = peer: "40-${peer.interface}";

  # The credential networkd reads the private key from.
  keyCredential = "radii.private-key";

  # Routing protocol of the watchdog's routes to devices, which babeld
  # announces from the hub a device uses.
  deviceRouteProtocol = 200;
in {
  options = let
    inherit (lib.extra) ip;
    inherit (lib.extra.types.ip) addressData addressWith networkWith;
    inherit (lib.attrsets) attrValues mapAttrs optionalAttrs;
    inherit (lib.lists) head length unique;
    inherit (lib.options) literalExpression mkEnableOption mkOption;
    inherit (lib.strings) hasInfix;
    inherit (lib.types) addCheck attrsOf coercedTo either enum ints listOf nonEmptyListOf nullOr port raw str strMatching submodule;

    # IP TYPES
    # --------
    # Text of either IP version is parsed by its look: a colon means IPv6.
    # Trying one version's parser on the other's text would throw instead of
    # falling through, as `either` needs.
    versionOf = text:
      if hasInfix ":" text
      then 6
      else 4;

    anyNetwork =
      coercedTo str (text: ip.network.fromCIDR (versionOf text) text)
      (either (networkWith {version = 4;}) (networkWith {version = 6;}));

    # An endpoint is an address of either version or a DNS name. Text made
    # only of address characters is parsed as an address, anything else is
    # kept as a name (so "[2001:db8::1]:51820" fails as a name, not as a
    # parse error).
    dnsName =
      strMatching "([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]{2,63}\\.?"
      // {description = "DNS name";};

    # Addresses are parsed by the coercion below, so this checks data only:
    # a parsing type here would try every name as an address and throw.
    singleHostData =
      addCheck addressData (address: ip.toCIDR address == ip.toCIDR (ip.address.singleHostRoute address))
      // {description = "single-host IP address";};

    endpoint = let
      looksLikeAddress = text: builtins.match "[0-9A-Fa-f:.]+" text != null;
    in
      coercedTo str (text:
        if looksLikeAddress text
        then ip.address.fromString (versionOf text) text
        else text)
      (either singleHostData dnsName);

    # SITE TABLE ENTRY
    # ----------------
    siteEntry = submodule ({name, ...}: {
      options = {
        id = mkOption {
          type = ints.positive;
          example = 3;
          description = ''
            Number of the host, unique across the site. A hub listens for
            this host on its `basePort` plus this number.
          '';
        };

        kind = mkOption {
          type = enum ["nixos" "device"];
          default = "nixos";
          description = ''
            `nixos` for a host built from this flake, which runs radii.
            `device` for anything else (a phone, a laptop with another
            system): it runs no routing daemon, so hubs reach it through
            static routes, and its tunnel is configured by hand.
          '';
        };

        hostAddress = mkOption {
          type = addressWith {
            version = 6;
            within = ip.ranges.ipv6.uniqueLocal;
            singleHost = true;
          };
          example = "fd00:1:2::1";
          description = ''
            The host's own address on the overlay: a single host within
            fc00::/7, as `lib.extra.ip` address data (/128). It may lie
            outside the host's `prefix`.
          '';
        };

        prefix = mkOption {
          type = nullOr (networkWith {
            version = 6;
            within = ip.ranges.ipv6.uniqueLocal;
            prefixLength = 48;
          });
          default = null;
          example = "fd00:1:2::/48";
          description = ''
            The host's ULA /48, for the containers it runs. Null for a host
            that only has its host address.
          '';
        };

        publicKey = mkOption {
          type = strMatching "[A-Za-z0-9+/]{43}=";
          description = ''
            The host's WireGuard public key, the same on all its tunnels.
          '';
        };

        availableNetworks = mkOption {
          type = nonEmptyListOf anyNetwork;
          example = ["0.0.0.0/0" "::/0"];
          description = ''
            Networks the host can reach hub endpoints through, as networks
            of either IP version. Hub endpoints outside all of them are left
            out of this host's candidates, e.g. `[ "0.0.0.0/0" ]` for a host
            with IPv4 only.
          '';
        };

        endpoints = mkOption {
          type = listOf endpoint;
          default = [];
          example = ["203.0.113.10" "2001:db8::10" "hub.example.org"];
          description = ''
            Where other hosts reach this host: addresses of either IP
            version or DNS names, without ports. A host with endpoints is a
            hub. Order sets preference.
          '';
        };

        basePort = mkOption {
          type = nullOr port;
          default = null;
          example = 51820;
          description = ''
            First port of a hub's listen range: it listens for each peer on
            `basePort` plus the peer's `id`. Every hub must set it.
          '';
        };

        presharedKey = mkOption {
          type = nullOr str;
          default = null;
          description = ''
            Reserved for pre-shared keys between peers. Unused: setting it
            changes nothing.
          '';
        };

        name = mkOption {
          type = str;
          readOnly = true;
          default = name;
          defaultText = literalExpression "<name>";
          description = "The entry's name in the site table.";
        };
      };
    });

    # DEVICE FILES
    # ------------
    # A device's tunnels as files: `file` for `nix build` (a wg-quick file
    # with the private key as a placeholder) and `qrCode` for `nix run`.
    deviceFiles = name: let
      tunnels = radii.deviceTunnels cfg.settings.site name;
      hubs = unique (map (tunnel: tunnel.hub) (attrValues tunnels));
    in
      lib.warnIf (length hubs == 1) "radii: ${name} reaches only one hub (${head hubs}): it has no failover"
      (mapAttrs (fileName: tunnel: rec {
          file = pkgs.writeText "${fileName}.conf" tunnel.text;

          # Prints the tunnel as a QR code for the WireGuard app. Given a
          # file holding the private key (or - for standard input), it fills
          # in the placeholder first; the key never enters the Nix store.
          qrCode = pkgs.writeShellApplication {
            name = "radii-${name}-${fileName}";
            runtimeInputs = [pkgs.qrencode];
            text = ''
              config=$(< ${file})

              if [ $# -gt 0 ]; then
                key=$(cat -- "$1")
                if ! [[ $key =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
                  echo "radii: $1 does not hold a WireGuard private key" >&2
                  exit 1
                fi
                config=''${config/"<private key>"/$key}
              fi

              printf '%s\n' "$config" | qrencode --type=ansiutf8
            '';
          };
        })
        tunnels);

    # Devices get `wg.<hub>-<n>` with their files; other hosts get nothing.
    withFiles = name: host:
      host // optionalAttrs (host.kind == "device") {wg = deviceFiles name;};
  in {
    services.radii = {
      enable = mkEnableOption "radii, the overlay between the site's hosts";

      privateKey = mkOption {
        type = nullOr str;
        default = null;
        example = literalExpression ''
          # systemd-creds encrypt --with-key=host --name=${keyCredential} radii.key -
          '''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAD…
          '''
        '';
        description = ''
          This host's WireGuard private key, encrypted for this host: the
          output of `systemd-creds encrypt --with-key=host
          --name=${keyCredential} <key file> -`, run on the host itself. Its
          public key is the one in the site table. Required when radii is
          enabled; systemd-networkd receives it as the credential
          `${keyCredential}`, and it never enters the Nix store unencrypted.
        '';
      };

      routeTable = mkOption {
        type = ints.between 1 4294967294;
        default = 6696;
        description = ''
          Routing table babeld installs the site's routes into. Two IPv6
          rules consult it: first `main` without its default route (so local
          routes, such as containers', win), then this table.
        '';
      };

      mtu = mkOption {
        type = ints.between 1280 1500;
        default = 1420;
        description = ''
          MTU of the tunnels: 1420 leaves room for WireGuard over IPv6 on a
          1500-byte link. Lower it where the link is smaller, e.g. 1412
          behind PPPoE.
        '';
      };

      watchdog = {
        interval = mkOption {
          type = ints.positive;
          default = 30;
          description = "Seconds between the endpoint watchdog's checks.";
        };

        staleAfter = mkOption {
          type = ints.positive;
          default = 180;
          description = ''
            Seconds without a handshake after which a tunnel counts as
            stale. A working tunnel renews its handshake about every two
            minutes. A stale tunnel to a hub moves to the hub's next
            endpoint; on a hub, a device whose tunnel is stale loses its
            route there.
          '';
        };
      };

      units = mkOption {
        type = raw;
        readOnly = true;
        default = let
          names = map unitOf (attrValues peers);
        in {
          netdevs = names;
          networks = names;
        };
        defaultText = literalExpression "{ netdevs = [ \"40-rd-<peer>\" … ]; networks = [ … ]; }";
        description = ''
          The units radii creates for its tunnels, as names in
          `systemd.network.netdevs` and `systemd.network.networks`, so a
          host can override them at once, e.g. to bring tunnels up only by
          hand:

              systemd.network.networks = lib.genAttrs config.services.radii.units.networks
                (_: { linkConfig.ActivationPolicy = "manual"; });

          The `radii` interface holding the host address is not among them.
        '';
      };

      settings = {
        self = mkOption {
          type = str;
          default = config.networking.hostName;
          defaultText = literalExpression "config.networking.hostName";
          description = "This host's name in the site table.";
        };

        site = mkOption {
          type = attrsOf siteEntry;
          default = {};
          example = literalExpression ''
            {
              collei = {
                id = 1;
                hostAddress = "fd00:1:2::1";
                prefix = "fd00:1:2::/48";
                publicKey = "…";
                availableNetworks = [ "::/0" ];
                endpoints = [ "2001:db8::10" ];
                basePort = 51820;
              };
              phone = {
                id = 7;
                kind = "device";
                hostAddress = "fd00:1:2::7";
                publicKey = "…";
                availableNetworks = [ "0.0.0.0/0" "::/0" ];
              };
            }
          '';
          description = ''
            Every host of the site, keyed by name: the same table on every
            host, so a change to it reaches every host that rebuilds.
            Set it once, in a module all hosts share.
          '';
        };
      };

      derived = mkOption {
        type = raw;
        readOnly = true;
        default = let
          derived = radii.derive cfg.settings.site cfg.settings.self;
        in
          derived
          // {
            hosts = mapAttrs withFiles derived.hosts;
            peers = mapAttrs withFiles derived.peers;
          };
        defaultText = literalExpression "derived from settings.site and settings.self";
        description = ''
          What radii derives from the site table, for its own use and for
          tests:

          - `hosts.<name>`: each entry, plus `role` (`hub` when it has
            endpoints, else `spoke`) and `ownedNetworks` (its /48, plus its
            host address as a /128 when that lies outside it)
          - `self`: this host's entry from `hosts`
          - `peers.<name>`: the hosts this host connects to (a spoke to
            every hub, a hub to every host), each from `hosts` plus
            `listenPort` (this host's port for that tunnel, null for any),
            `endpointPort` (the port of the peer's endpoints, null when
            the peer is a spoke) and `candidates` (the peer's endpoints
            within this host's `availableNetworks`; DNS names always), and
            for the tunnel: `interface` (`rd-<peer>`), `linkLocal.self` and
            `linkLocal.peer` (`fe80::<id>/64` on each end), `allowedIPs`
            (`::/0` towards a hub; a spoke's owned networks, link-local
            address and babel's group on a hub) and `endpoint` (where the
            tunnel to a hub starts, null towards a spoke) and
            `acceptedNetworks` (the routes babeld takes from that peer)
          - `hosts.<device>.wg.<hub>-<n>` (also under `peers` on hubs):
            a device's WireGuard tunnels, one per hub and endpoint it can
            reach, `n` counting the hub's endpoints in preference order.
            Each has `file`, a wg-quick file with `<private key>` as a
            placeholder, and `qrCode`, which prints it as a QR code and
            fills in the key from a file argument (or `-` for standard
            input). Only devices have `wg`. For example, from any host with
            the site table:

                nix build .#nixosConfigurations.<host>.config.services.radii.derived.hosts.keqing.wg.beidou-1.file
                nix run .#nixosConfigurations.<host>.config.services.radii.derived.hosts.keqing.wg.beidou-1.qrCode -- keqing.key

          Ports are null while a hub has no `basePort`.
        '';
      };
    };
  };

  config = let
    inherit (lib.extra) ip;
    inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
    inherit (lib.attrsets) attrValues listToAttrs mapAttrs' nameValuePair optionalAttrs;
    inherit (lib.lists) any concatMap filter last optional optionals unique;
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.strings) concatLines concatStringsSep fixedWidthString hasInfix splitString toLower;
    inherit (lib.meta) getExe;
    inherit (lib.trivial) toHexString;
  in
    mkIf cfg.enable (mkMerge [
      # CHECKS
      # ------
      (let
        inherit (cfg.settings) self site;
        host = radii.checkHost site self;

        errors = unique (
          radii.checkSite site
          ++ host.errors
          ++ optional (site ? ${self} && site.${self}.kind != "nixos")
          "${self} is a device in the site table: only hosts of kind nixos run radii"
          ++ optional (cfg.privateKey == null)
          "services.radii.privateKey is not set: ${self} has no key for its tunnels"
        );
      in {
        assertions = [
          {
            assertion = errors == [];
            message = concatStringsSep "\n" (["radii: the site table has problems:"] ++ map (error: "  ${error}") errors);
          }
        ];

        warnings = map (warning: "radii: ${warning}") host.warnings;
      })

      # TUNNELS
      # -------
      # One WireGuard interface per peer, so each peer is its own link: babel
      # can run on every tunnel, and a hub can tell spokes apart. No routes
      # come from WireGuard itself (RouteTable=off); babeld provides them.
      {
        systemd.services.systemd-networkd.serviceConfig.SetCredentialEncrypted =
          optionals (cfg.privateKey != null) (mkSetCredentialEncrypted {${keyCredential} = cfg.privateKey;});

        systemd.network = {
          netdevs =
            {
              # The host address lives on its own interface, apart from any
              # tunnel, so it stays up whichever tunnels are.
              "40-radii".netdevConfig = {
                Kind = "dummy";
                Name = "radii";
              };
            }
            // mapAttrs' (_: peer:
              nameValuePair (unitOf peer) {
                netdevConfig = {
                  Kind = "wireguard";
                  Name = peer.interface;
                };

                wireguardConfig =
                  {
                    PrivateKeyFile = "${credentialsDirectory "systemd-networkd"}/${keyCredential}";
                    RouteTable = "off";
                  }
                  # A spoke binds no fixed port.
                  // optionalAttrs (peer.listenPort != null) {ListenPort = peer.listenPort;};

                wireguardPeers = [
                  ({
                      PublicKey = peer.publicKey;
                      AllowedIPs = map ip.toCIDR peer.allowedIPs;
                      RouteTable = "off";
                    }
                    # Towards a hub: where to start, and keep NAT open.
                    // optionalAttrs (peer.endpoint != null) {
                      Endpoint = peer.endpoint;
                      PersistentKeepalive = 25;
                    })
                ];
              })
            peers;

          networks =
            {
              "40-radii" = {
                matchConfig.Name = "radii";
                address = [(ip.toCIDR cfg.derived.self.hostAddress)];
                networkConfig.LinkLocalAddressing = "no";
                linkConfig.RequiredForOnline = "no";
              };
            }
            // mapAttrs' (_: peer:
              nameValuePair (unitOf peer) {
                matchConfig.Name = peer.interface;
                address = [(ip.toCIDR peer.linkLocal.self)];
                networkConfig = {
                  LinkLocalAddressing = "no";
                  IPv6AcceptRA = false;
                };
                linkConfig = {
                  RequiredForOnline = "no";
                  MTUBytes = toString cfg.mtu;
                  # WireGuard links lack the flag; babel sends hellos by multicast.
                  Multicast = true;
                };
              })
            peers;
        };

        # A hub opens exactly its listen ports, one per peer.
        networking.firewall.allowedUDPPorts =
          attrValues peers
          |> filter (peer: peer.listenPort != null)
          |> map (peer: peer.listenPort);
      }

      # ROUTING
      # -------
      # babeld on every tunnel to a NixOS peer. Each host announces what it
      # owns; what a peer may announce is filtered by who it is. Routes land
      # in their own table, consulted after main's specific routes.
      (let
        me = cfg.derived.self;

        # Devices run no babel; the watchdog routes to them instead.
        babelPeers = filter (peer: peer.kind == "nixos") (attrValues peers);
        devicePeers = filter (peer: peer.kind == "device") (attrValues peers);

        lengthOf = network: last (splitString "/" (ip.toCIDR network));

        # `<prefix> eq <length>`: exactly that network, not what lies in it.
        exactly = network: "ip ${ip.toCIDR network} eq ${lengthOf network}";

        # The host address needs announcing on its own only outside the /48.
        hostAddressOutside = me.prefix == null || !(ip.network.contains me.prefix me.hostAddress);

        # Unique per host, from its site id: babeld cannot derive one from
        # WireGuard links, which have no hardware address.
        routerId = let
          hex = fixedWidthString 4 "0" (toLower (toHexString me.id));
        in "00:00:00:00:00:00:${builtins.substring 0 2 hex}:${builtins.substring 2 2 hex}";
      in {
        # The /48 as a route babeld can announce. It leads to the dummy
        # interface, which drops what no container route claims.
        systemd.network.networks."40-radii" = {
          routes = optional (me.prefix != null) {
            Destination = ip.toCIDR me.prefix;
            Protocol = "static";
          };

          routingPolicyRules = [
            {
              Family = "ipv6";
              Priority = 1000;
              Table = "main";
              SuppressPrefixLength = 0;
            }
            {
              Family = "ipv6";
              Priority = 1001;
              Table = cfg.routeTable;
            }
          ];
        };

        services.babeld = {
          enable = true;

          interfaces = listToAttrs (map (peer: nameValuePair peer.interface {type = "tunnel";}) babelPeers);

          extraConfig = concatLines (
            [
              "router-id ${routerId}"
              "export-table ${toString cfg.routeTable}"
            ]
            # From each peer, only what it may announce.
            ++ concatMap (peer:
              map (network: "in if ${peer.interface} ${exactly network} allow") peer.acceptedNetworks
              ++ ["in if ${peer.interface} deny"])
            babelPeers
            ++ ["in deny"]
            # A spoke passes on nothing it learned, so it never carries
            # traffic between hubs.
            ++ optionals (me.role == "spoke") (
              map (network: "out ${exactly network} allow") me.ownedNetworks
              ++ ["out deny"]
            )
            # Announce what this host owns, and nothing else.
            ++ optional (me.prefix != null) "redistribute ${exactly me.prefix} proto 4 allow"
            ++ optional hostAddressOutside "redistribute local ip ${ip.toCIDR me.hostAddress} eq 128 allow"
            # On hubs, each device while the watchdog routes to it here.
            ++ map (device: "redistribute ${exactly device.hostAddress} proto ${toString deviceRouteProtocol} allow") devicePeers
            ++ [
              "redistribute local deny"
              "redistribute deny"
            ]
          );
        };

        # Babel speaks UDP 6696 on its tunnels only.
        networking.firewall.interfaces = listToAttrs (map (peer: nameValuePair peer.interface {allowedUDPPorts = [6696];}) babelPeers);
      })

      # ENDPOINT WATCHDOG
      # -----------------
      # Moves stale tunnels to a hub's next endpoint, and on hubs routes to
      # devices only while their tunnels are alive. The script lives in
      # _module/watchdog.sh; its configuration is generated here.
      (let
        me = cfg.derived.self;

        # Tunnels to hubs with somewhere to go.
        hubPeers = filter (peer: peer.role == "hub" && peer.candidates != [] && peer.endpointPort != null) (attrValues peers);
        devicePeers = filter (peer: peer.kind == "device") (attrValues peers);

        candidate = peer: endpoint:
          if ip.isAddress endpoint
          then "a,${radii.endpointText endpoint peer.endpointPort}"
          else "n,${endpoint},${toString peer.endpointPort}";

        # Address families this host can reach endpoints through.
        uses = version:
          if any (network: hasInfix ":" (ip.toCIDR network) == (version == 6)) me.availableNetworks
          then "1"
          else "0";

        configuration = pkgs.writeText "radii-watchdog.conf" (concatLines (
          [
            "stale ${toString cfg.watchdog.staleAfter}"
            "settle ${toString (2 * cfg.watchdog.interval)}"
            "proto ${toString deviceRouteProtocol}"
            "ipv4 ${uses 4}"
            "ipv6 ${uses 6}"
          ]
          ++ map (peer: "hub ${peer.interface} ${peer.publicKey} ${concatStringsSep " " (map (candidate peer) peer.candidates)}") hubPeers
          ++ map (peer: "device ${peer.interface} ${peer.publicKey} ${ip.toCIDR peer.hostAddress}") devicePeers
        ));

        watchdog = pkgs.writeShellApplication {
          name = "radii-watchdog";
          runtimeInputs = with pkgs; [coreutils gawk getent iproute2 wireguard-tools];
          text = builtins.readFile ./_module/watchdog.sh;
        };
      in {
        systemd.services.radii-watchdog = {
          description = "radii endpoint watchdog";
          after = ["systemd-networkd.service"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${getExe watchdog} ${configuration}";
            RuntimeDirectory = "radii-watchdog";
            RuntimeDirectoryPreserve = true;
            CapabilityBoundingSet = ["CAP_NET_ADMIN"];
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6"];
          };
        };

        systemd.timers.radii-watchdog = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "${toString cfg.watchdog.interval}s";
          };
        };
      })
    ]);
}
