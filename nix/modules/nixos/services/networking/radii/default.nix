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

  # Spokes depend on hubs, so a hub keeps its tunnels and host address up,
  # bringing them back whatever happens to them. A plain value: NixOS checks
  # networkd's [Link] settings before mkDefault or mkIf are resolved.
  hubLink = lib.attrsets.optionalAttrs (cfg.settings.site ? ${cfg.settings.self} && cfg.derived.self.role == "hub") {
    ActivationPolicy = "always-up";
  };

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
    inherit (lib.lists) head last length unique;
    inherit (lib.options) literalExpression mkEnableOption mkOption;
    inherit (lib.strings) hasInfix;
    inherit (lib.types) addCheck attrsOf bool coercedTo either enum ints listOf nonEmptyListOf nullOr port raw str strMatching submodule;

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

        openPorts = mkOption {
          type = let
            range = submodule {
              options = {
                from = mkOption {
                  type = port;
                  description = "First port of the range.";
                };
                to = mkOption {
                  type = port;
                  description = "Last port of the range.";
                };
              };
            };

            # `[ from to ]`, exactly two ports, is a range too.
            pair =
              addCheck (listOf port) (ports: length ports == 2)
              // {description = "list of two ports, [ from to ]";};
          in
            nullOr (listOf (either port (coercedTo pair (ports: {
                from = head ports;
                to = last ports;
              })
              range)));
          default = null;
          example = literalExpression "[ 50011 [ 50013 50015 ] ]";
          description = ''
            The UDP ports a hub's router or provider firewall lets through to
            it, as ports or ranges (`[ from to ]`, or `{ from; to; }`): what the
            administrator has opened outside the host, recorded here. Every
            hub must set it. A range includes both ends; a list of anything
            but two ports is an error, not a list of ports.

            A hub needs one port per peer that can reach it (`basePort` plus
            the peer's `id`). Until all of them are listed, the hub's build and
            the site check fail and name each missing port, the peer it is
            for and the endpoints that peer uses, so the administrator knows
            what to open (an IPv4 forward on a router, an IPv6 opening on a
            firewall). Listed ports no peer uses are reported too, so they can
            be closed again. The hub's own firewall opens exactly the ports it
            needs.

            Leave it unset on spokes and devices.
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
        # babeld writes the table into rtm_table, which holds one byte, and
        # sends no RTA_TABLE: a larger number wraps (6696 lands in table 40).
        # 253 to 255 are the kernel's default, main and local.
        type = ints.between 1 252;
        default = 96;
        description = ''
          Routing table babeld installs the site's routes into. Two IPv6
          rules consult it: first `main` without its default route (so local
          routes, such as containers', win), then this table. At most 252:
          babeld cannot address tables above 255, and 253 to 255 are the
          kernel's own.
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
          # A working tunnel's handshake gets up to about 150 seconds old
          # (WireGuard renews it after 120, on the next keepalive), so
          # anything lower calls working tunnels stale.
          type = ints.between 150 86400;
          default = 180;
          description = ''
            Seconds without a handshake after which a tunnel counts as
            stale, at least 150: a working tunnel renews its handshake
            about every two minutes. A stale tunnel to a hub moves to the
            hub's next endpoint; on a hub, a device whose tunnel is stale
            loses its route there.
          '';
        };

        onNetworkChange = mkOption {
          type = bool;
          default = cfg.settings.site ? ${cfg.settings.self} && cfg.derived.self.role == "spoke";
          defaultText = literalExpression "true on spokes, false on hubs";
          description = ''
            Also run the watchdog whenever a link becomes routable (through
            networkd-dispatcher), not only on its timer. A host that changes
            networks, such as a laptop moving to an IPv4-only network, then
            leaves an endpoint it has no route to within seconds. Hubs stay
            where they are, so it is off for them.
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
          Only spokes may do this: hubs set `always-up`, and an assertion
          fails if one of a hub's units is set to `manual`, `down`,
          `always-down` or left unmanaged.
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

        hostAccess = {
          allow = mkOption {
            type = listOf (submodule {
              options = {
                sources = mkOption {
                  type = nonEmptyListOf (either singleHostData (networkWith {version = 6;}));
                  example = literalExpression "[ (getULA colleiContainers.porti.<mid> |> ip.address.singleHostRoute) ]";
                  description = ''
                    Where the connections may come from: IPv6 single-host
                    addresses or networks, as `lib.extra.ip` data.
                  '';
                };
                protocol = mkOption {
                  type = enum ["tcp" "udp"];
                  description = "The transport protocol.";
                };
                ports = mkOption {
                  type = nonEmptyListOf port;
                  description = "The ports on this host they may connect to.";
                };
              };
            });
            default = [];
            description = ''
              Exceptions to the overlay's rule for this host: through radii's
              tunnels, only the site's hosts themselves (devices included) may
              open connections to this host. Everything else that comes
              through a tunnel, in practice containers on other hosts, is
              dropped and counted (`container-to-host` in the `radii` table),
              whatever this host's firewall opens. Each entry here lets its
              sources reach the given ports anyway; the host's firewall must
              still open them.

              Traffic this host forwards (to its containers, or between other
              hosts on a hub) is not affected: sigil's traffic rules decide
              it. Neither are this host's own containers, which arrive on
              their veths, not through a tunnel.
            '';
          };
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
    inherit (lib.strings) concatLines concatMapStringsSep concatStringsSep fixedWidthString hasInfix optionalString splitString toLower;
    inherit (lib.meta) getExe;
    inherit (lib.trivial) toHexString;
  in
    mkIf cfg.enable (mkMerge [
      # CHECKS
      # ------
      (let
        inherit (cfg.settings) self site;
        host = radii.checkHost site self;

        # Spokes depend on hubs, so a hub's tunnels and host address stay up;
        # spokes may bring theirs up by hand.
        isHub = site ? ${self} && cfg.derived.self.role == "hub";
        hubUnits = ["40-radii"] ++ map unitOf (attrValues peers);
        heldDown =
          hubUnits
          |> concatMap (unit: let
            link = config.systemd.network.networks.${unit}.linkConfig or {};
            policy = link.ActivationPolicy or null;
          in
            optional (builtins.elem policy ["manual" "down" "always-down"])
            "${self} is a hub but sets ActivationPolicy=${policy} on ${unit}: hubs keep their tunnels up"
            ++ optional (builtins.elem (link.Unmanaged or false) [true "yes" "true" "on" "1"])
            "${self} is a hub but leaves ${unit} unmanaged: hubs keep their tunnels up");

        errors = unique (
          radii.checkSite site
          ++ host.errors
          ++ optional (site ? ${self} && site.${self}.kind != "nixos")
          "${self} is a device in the site table: only hosts of kind nixos run radii"
          ++ optional (cfg.privateKey == null)
          "services.radii.privateKey is not set: ${self} has no key for its tunnels"
          ++ optional (!config.systemd.network.enable)
          "systemd.network.enable is not set: radii's tunnels and rules are systemd-networkd units"
          ++ optional (!config.networking.nftables.enable)
          "networking.nftables.enable is not set: radii validates overlay sources with nftables"
          ++ (
            cfg.settings.hostAccess.allow
            |> concatMap (rule: rule.sources)
            |> filter (source: !(hasInfix ":" (ip.toCIDR source)))
            |> map (source: "settings.hostAccess.allow has the IPv4 source ${ip.toCIDR source}: the overlay carries IPv6 only")
          )
          ++ optionals isHub heldDown
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
                linkConfig = {RequiredForOnline = "no";} // hubLink;
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
                linkConfig =
                  {
                    RequiredForOnline = "no";
                    MTUBytes = toString cfg.mtu;
                    # WireGuard links lack the flag; babel sends hellos by multicast.
                    Multicast = true;
                  }
                  // hubLink;
              })
            peers;
        };

        # A hub opens the port of every peer that can reach it, the ports its
        # openPorts must list (an assertion holds it to that). Peers that
        # cannot reach it (no endpoint in their availableNetworks) get none.
        networking.firewall.allowedUDPPorts =
          radii.inboundPorts cfg.settings.site cfg.settings.self
          |> map (entry: entry.port);
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

        # Every network of the site but this host's own.
        siteNetworks =
          attrValues cfg.derived.hosts
          |> filter (host: host.name != me.name)
          |> concatMap (host: host.ownedNetworks);

        # Above babeld's routes (1024) and its placeholders for routes it
        # is retracting (65535), so a fallback only answers when babeld
        # has nothing.
        fallbackMetric = 100000;
      in {
        # The /48 as a route babeld can announce. It leads to the dummy
        # interface, which drops what no container route claims.
        systemd.network.networks."40-radii" = {
          routes =
            optional (me.prefix != null) {
              Destination = ip.toCIDR me.prefix;
              Protocol = "static";
            }
            # While babeld has no route to a network of the site (tunnels
            # down, babeld stopped, hubs out of reach), it is unreachable:
            # without this the lookup goes on to main's default route and
            # the site's traffic leaves through the uplink, unencrypted.
            ++ map (network: {
              Destination = ip.toCIDR network;
              Type = "unreachable";
              Table = cfg.routeTable;
              Metric = fallbackMetric;
            })
            siteNetworks;

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

        # babeld's routes are not in any .network file, so networkd would
        # remove them as foreign routes. This applies to the whole host.
        systemd.network.config.networkConfig.ManageForeignRoutes = false;

        services.babeld = {
          enable = true;

          interfaces = listToAttrs (map (peer: nameValuePair peer.interface {type = "tunnel";}) babelPeers);

          extraConfig = concatLines (
            [
              "router-id ${routerId}"
              "export-table ${toString cfg.routeTable}"
              # Traffic this host sends into the overlay leaves from its host
              # address, the one source hubs accept from it. Left to itself,
              # the kernel may pick another ULA (e.g. one on the LAN) that
              # shares more bits with the destination.
              "install pref-src ${me.hostAddress |> ip.toCompressed}"
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

      # SOURCE VALIDATION
      # -----------------
      # Whoever owns a range enforces where its addresses may come from.
      # Hubs' AllowedIPs for each spoke are the first check; this is the
      # receiving host's. Always on: it drops only forged traffic, so its
      # counters stay at zero. Runs at priority raw, before conntrack and the
      # routing decision.
      (let
        me = cfg.derived.self;

        # Towards hubs, WireGuard accepts any source (AllowedIPs ::/0). On
        # tunnels to spokes and devices it already accepts only what the
        # peer owns, so they need no second look.
        quoted = peer: ''"${peer.interface}"'';
        hubInterfaces = attrValues peers |> filter (peer: peer.role == "hub") |> map quoted;
        tunnelInterfaces = attrValues peers |> map quoted;
      in {
        # NixOS's reverse-path filter is strict on every interface, which
        # would drop replies that come back through the other hub. Radii's
        # tunnels are checked here and by WireGuard instead.
        networking.firewall.extraReversePathFilterRules =
          optionalString (tunnelInterfaces != []) "iifname { ${concatStringsSep ", " tunnelInterfaces} } accept";

        networking.nftables.tables.radii = {
          family = "inet";
          content = ''
            counter forged-on-tunnel {
              comment "from a tunnel to a hub, with a source the site does not route through a tunnel"
            }

            counter own-network-from-outside {
              comment "with a source this host owns, from anywhere but itself or its containers"
            }

            set owned {
              type ipv6_addr
              flags interval
              elements = { ${concatStringsSep ", " (map ip.toCIDR me.ownedNetworks)} }
            }

            chain validate-source {
              type filter hook prerouting priority raw; policy accept;

              # From a hub: the source must be one the site routes through a
              # tunnel of this host (loose reverse path within the overlay;
              # paths through the two hubs need not be symmetric). Link-local
              # sources are the hub itself.
              ${optionalString (hubInterfaces != []) "iifname { ${concatStringsSep ", " hubInterfaces} } ip6 saddr != fe80::/10 fib saddr oifname != { ${concatStringsSep ", " tunnelInterfaces} } counter name forged-on-tunnel drop"}

              # This host's own networks come only from itself (lo) and its
              # containers (ve-*, which sigil validates): never from the
              # uplink or a tunnel.
              ip6 saddr @owned iifname != "lo" iifname != "ve-*" counter name own-network-from-outside drop
            }
          '';
        };
      })

      # HOST ACCESS
      # -----------
      # radii routes every host's /48, which would let containers on other
      # hosts reach whatever this host opens. Through the tunnels, only the
      # site's hosts themselves (devices included) may open connections to
      # this host, plus what settings.hostAccess.allow lets in. Runs on the
      # input hook, so forwarded traffic never meets it, and drops only: the
      # host's firewall still decides what is open at all.
      (let
        quoted = peer: ''"${peer.interface}"'';
        tunnels = concatStringsSep ", " (attrValues peers |> map quoted);

        hostAddresses = attrValues cfg.derived.hosts |> map (host: ip.toCIDR host.hostAddress);

        exception = rule: "iifname { ${tunnels} } ip6 saddr { ${concatMapStringsSep ", " ip.toCIDR rule.sources} } ${rule.protocol} dport { ${concatMapStringsSep ", " toString rule.ports} } accept";
      in {
        networking.nftables.tables.radii.content = optionalString (peers != {}) ''
          counter container-to-host {
            comment "a new connection to this host through a tunnel, from an address that is not a host of the site"
          }

          set site-hosts {
            type ipv6_addr
            flags interval
            elements = { ${concatStringsSep ", " hostAddresses} }
          }

          chain guard-host {
            type filter hook input priority filter; policy accept;

            # Exceptions from settings.hostAccess.allow.
            ${concatMapStringsSep "\n" exception cfg.settings.hostAccess.allow}

            # Other hosts' containers (anything but a host of the site) may
            # not open connections to this host. Link-local sources are the
            # tunnels' other ends, babel among them.
            iifname { ${tunnels} } ct state new ip6 saddr != @site-hosts ip6 saddr != fe80::/10 counter name container-to-host drop
          }
        '';
      })

      # ENDPOINT WATCHDOG
      # -----------------
      # Moves tunnels off endpoints this host has no route to, and stale ones
      # to a hub's next endpoint; on hubs, routes to devices only while their
      # tunnels are alive. The script lives in _module/watchdog.sh; its
      # configuration is generated here.
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
            # Timers are a minute coarse by default, which would stretch
            # any shorter interval.
            AccuracySec = "1s";
          };
        };

        # A link that becomes routable may have brought another network: the
        # watchdog checks right away whether each tunnel's endpoint still has
        # a route. radii's own links becoming routable changes nothing.
        services.networkd-dispatcher = mkIf cfg.watchdog.onNetworkChange {
          enable = true;
          rules.radii-watchdog = {
            onState = ["routable"];
            script = ''
              #!${pkgs.runtimeShell}
              case "$IFACE" in
              rd-* | radii) exit 0 ;;
              esac
              exec ${config.systemd.package}/bin/systemctl start --no-block radii-watchdog.service
            '';
          };
        };
      })
    ]);
}
