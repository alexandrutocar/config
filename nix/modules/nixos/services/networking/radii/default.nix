{
  config,
  lib,
  ...
}: let
  cfg = config.services.radii;

  # Derivation and checks, shared with the flake check.
  radii = import ./_tests/lib {inherit lib;};
in {
  options = let
    inherit (lib.extra) ip;
    inherit (lib.extra.types.ip) addressData addressWith networkWith;
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
  in {
    services.radii = {
      enable = mkEnableOption "radii, the overlay between the site's hosts";

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
        default = radii.derive cfg.settings.site cfg.settings.self;
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
            within this host's `availableNetworks`; DNS names always)

          Ports are null while a hub has no `basePort`.
        '';
      };
    };
  };

  config = let
    inherit (lib.lists) optional unique;
    inherit (lib.modules) mkIf;
    inherit (lib.strings) concatStringsSep;
  in
    mkIf cfg.enable (let
      inherit (cfg.settings) self site;
      host = radii.checkHost site self;

      errors = unique (
        radii.checkSite site
        ++ host.errors
        ++ optional (site ? ${self} && site.${self}.kind != "nixos")
        "${self} is a device in the site table: only hosts of kind nixos run radii"
      );
    in {
      assertions = [
        {
          assertion = errors == [];
          message = concatStringsSep "\n" (["radii: the site table has problems:"] ++ map (error: "  ${error}") errors);
        }
      ];

      warnings = map (warning: "radii: ${warning}") host.warnings;
    });
}
