{
  modulesPath,
  options,
  config,
  pkgs,
  lib,
  self,
  ...
} @ host: let
  globalConfig = config;
  cfg = config.services.sigil;
in let
  mkBridgeName = bid: "br-${bid}";
  mkLHLinkName = bid: mid: "lh-${builtins.substring 0 12 (builtins.hashString "sha256" (bid + mid))}";
  mkLCLinkName = bid: mid: "lc-${builtins.substring 0 12 (builtins.hashString "sha256" (bid + mid))}";

  # LINK-LOCAL ADDRESSING
  # ---------------------
  # Every veth (host ve-* <-> container host0) and every container link (lc-*)
  # is its own fe80::/64, so the same few addresses repeat on each of them.
  # Built from the link network, so each carries /64 and lies within fe80::/10.
  # Handed to the containers as `sigil.linkLocal`.
  linkLocal = let
    on = lib.extra.ip.network.hostAddress (lib.extra.ip.network.fromCIDR 6 "fe80::/64");
  in {
    host = on "::1"; # ve-* end on the host
    container = on "::c"; # host0 end in the container
    peerA = on "::a"; # lc-* end of the linked container with the lower MID
    peerB = on "::b"; # lc-* end of the other linked container
  };
in {
  options = let
    inherit (lib) hashString;
    inherit (lib.extra) ip;
    inherit (lib.extra.types.ip) addressWith networkWith;
    inherit (lib.extra.files.list) recursive;
    inherit (lib.attrsets) attrByPath attrNames attrValues mapAttrs mergeAttrsList;
    inherit (lib.lists) any concatMap elemAt foldl' length optional optionals singleton sort;
    inherit (lib.modules) mkBefore;
    inherit (lib.options) literalExpression mkEnableOption mkOption;
    inherit (lib.types) attrsOf bool deferredModule either enum ints listOf mkOptionType nonEmptyListOf nullOr raw str submodule;
    inherit (lib.strings) concatStringsSep substring;
    inherit (lib.trivial) fromHexString;

    # IP TYPES
    # --------
    # Container addresses are single IPv6 hosts (/128) of the right scope.
    # Strings are still accepted and parsed; values are `lib.extra.ip` data.
    singleHostWithin = within:
      addressWith {
        version = 6;
        inherit within;
        singleHost = true;
      };

    # HOST PARTS
    # ----------
    # Addresses set by the user are written as host parts: the low 64
    # bits only ("::10"), i.e. single hosts within ::/64. `apply` puts
    # them on their /64, so they read back as full addresses.
    hostParts = ip.network.fromCIDR 6 "::/64";
  in {
    services.sigil = {
      enable = mkEnableOption "sigil";

      settings = {
        containers = mkOption {
          type = let
            # A single container, parameterized over the group it is declared in.
            # `mid` defaults to the attribute name and `group` to the enclosing
            # attribute, so neither has to be set at the call site.
            containerModule = let
              # ADDRESS DERIVATION
              # ------------------
              # The container's single host on a /64: its 64-bit interface
              # identifier is the first 16 hex digits of sha256(mid). Same
              # addresses as the former "<prefix>:<aaaa:bbbb:cccc:dddd>" strings.
              getHostAddress = subnet: mid:
                ip.address.singleHostRoute
                (ip.network.hostAddressFromHex subnet (hashString "sha256" mid));

              # The group's /64 within the ULA /48: the first 4 hex digits of
              # sha256(group) select one of its 2^16 subnets. Same subnets as the
              # former "<prefix>:<first 4 hex digits>" strings.
              getULASubnet = prefix: group:
                ip.network.subnetAt prefix 64
                (fromHexString (substring 0 4 (hashString "sha256" group)));
            in
              group:
                submodule (
                  {
                    config,
                    name,
                    ...
                  } @ containerArgs: {
                    options = let
                      # EVALUATION
                      # ----------
                      # Address book handed to the container's own module system through
                      # `specialArgs.sigil`.
                      infosFor = container: {
                        inherit (container) mid group addresses;
                        links = linksFor container;
                      };

                      # Links declared for a container under
                      # `settings.network.links.<group>.<id>`, if any.
                      linksFor = container: let
                        policies = {
                          outgoing = attrByPath [container.group container.mid] [] cfg.settings.network.links;

                          incoming = concatMap (
                            group:
                              concatMap (
                                source:
                                  builtins.filter (l: l.target.mid == container.mid) group.${source}
                              ) (builtins.attrNames group)
                          ) (builtins.attrValues cfg.settings.network.links);
                        };

                        bridges = attrValues (foldl' (acc: link:
                          if acc ? ${link.bid}
                          then acc
                          else
                            acc
                            // {
                              ${link.bid} = {
                                inherit (link) bid;
                                port =
                                  if link.source.mid == container.mid
                                  then link.target
                                  else link.source;
                              };
                            }) {}
                        (policies.outgoing ++ policies.incoming));
                      in {
                        lib = {
                          bridge = {
                            mapToAttrs = f: mergeAttrsList (map f bridges);
                            mapToList = f: concatMap f bridges;
                          };
                          policy = {
                            mapToAttrs = f: mergeAttrsList (map f policies.outgoing);
                            mapToList = f: concatMap f policies.outgoing;
                          };
                        };
                      };

                      # HOST PART RESOLUTION
                      # --------------------
                      # The container's group /64, home of its ULA and ULA extras.
                      ulaSubnet = getULASubnet cfg.settings.network.ula.prefix config.group;

                      onSubnet = subnet: hostPart:
                        ip.address.singleHostRoute (ip.network.hostAddress subnet hostPart);

                      # Throws without a GUA prefix; the assertion on
                      # addressesWithoutPrefix reports this first, for all containers.
                      onGUAPrefix = label: hostPart: let
                        prefix = cfg.settings.network.gua.prefix;
                      in
                        if prefix == null
                        then throw "sigil: ${config.group}/${config.mid} sets addresses.ipv6.${label}, but settings.network.gua.prefix is not set"
                        else onSubnet prefix hostPart;
                    in {
                      addresses = {
                        ipv6 = {
                          gua = mkOption {
                            type = nullOr (singleHostWithin hostParts);
                            default =
                              if cfg.settings.network.gua.prefix == null
                              then null
                              else getHostAddress hostParts config.mid;
                            defaultText = literalExpression ''
                              if config.services.sigil.settings.network.gua.prefix == null
                              then null
                              else "::<iid>"
                              # <iid>: first 16 hex digits of sha256(mid)
                            '';
                            example = "::10";
                            apply = hostPart:
                              if hostPart == null
                              then null
                              else onGUAPrefix "gua" hostPart;
                            description = ''
                              Globally routable address of the container.

                              Set as a host part on `settings.network.gua.prefix`,
                              e.g. `"::10"`. It reads back as the full address, as
                              `lib.extra.ip` address data (/128). Render with
                              `lib.extra.ip.toCompressed` or `toCIDR`.

                              Defaults to the container's derived interface
                              identifier when a GUA prefix is set, and to null
                              otherwise. Set it to null to opt out. Setting it
                              without a GUA prefix is an error, and so is the
                              host part `::` (the subnet-router anycast address).

                              Opting out while keeping `extra.gua` addresses leaves
                              the container reachable on them, but its outgoing
                              internet traffic then leaves from its ULA and fails:
                              extras are never chosen as source addresses.
                            '';
                          };

                          ula = mkOption {
                            type = singleHostWithin ip.ranges.ipv6.uniqueLocal;
                            readOnly = true;
                            default = getHostAddress ulaSubnet config.mid;
                            defaultText = literalExpression ''
                              <ula prefix>:<subnet>:<iid>/128
                              # <subnet>: first 4 hex digits of sha256(group)
                              # <iid>: first 16 hex digits of sha256(mid)
                            '';
                            description = ''
                              The container's identity on the internal network: a
                              unique local address derived from its group and MID, as
                              `lib.extra.ip` address data (/128, within fc00::/7).
                              Always present and read-only, so it stays unique across
                              hosts without coordination; a container's ULA changes
                              only with its group or MID.
                              Render with `lib.extra.ip.toCompressed` or `toCIDR`.
                            '';
                          };

                          extra = {
                            ula = mkOption {
                              type = attrsOf (singleHostWithin hostParts);
                              default = {};
                              example = {dns = "::53";};
                              apply = mapAttrs (_: onSubnet ulaSubnet);
                              description = ''
                                Additional unique local addresses, keyed by a name of
                                your choosing. Set as host parts on the container's
                                group /64 (that of its ULA), e.g. `dns = "::53"`; each
                                reads back as the full address, as `lib.extra.ip`
                                address data (/128).

                                They are added to `lo` as deprecated addresses: they
                                accept traffic but are never chosen as source
                                addresses, so a service that must send from one has
                                to bind to it. The host part `::` is an error, and so
                                is an address held twice, by this or another container.
                              '';
                            };

                            gua = mkOption {
                              type = attrsOf (singleHostWithin hostParts);
                              default = {};
                              apply = mapAttrs (name: onGUAPrefix "extra.gua.${name}");
                              description = ''
                                Additional globally routable addresses, keyed by a
                                name of your choosing. Set as host parts on
                                `settings.network.gua.prefix`, e.g. `ssh = "::22"`;
                                each reads back as the full address, as
                                `lib.extra.ip` address data (/128).

                                They are added to `lo` as deprecated addresses: they
                                accept traffic but are never chosen as source
                                addresses, so a service that must send from one has
                                to bind to it. Setting any without a GUA prefix is an
                                error, as are the host part `::` and an address held
                                twice, by this or another container.
                              '';
                            };
                          };
                        };
                      };

                      addressesWithoutPrefix = mkOption {
                        type = listOf str;
                        internal = true;
                        visible = false;
                        readOnly = true;
                        # Read from the raw definitions, so nothing is resolved
                        # (resolving a host part without its prefix throws).
                        default = optionals (cfg.settings.network.gua.prefix == null) (
                          optional (any (hostPart: hostPart != null) containerArgs.options.addresses.ipv6.gua.definitions) "gua"
                          # Names only: their values are not resolved.
                          ++ map (name: "extra.gua.${name}") (attrNames config.addresses.ipv6.extra.gua)
                        );
                        description = ''
                          Labels (relative to `addresses.ipv6`) of host parts this
                          container sets although their prefix is not configured.
                          Collected by an assertion that lists every such container.
                        '';
                      };

                      rules = {
                        networkTraffic = let
                          # TRAFFIC RULES
                          # -------------
                          # One incoming rule: traffic from any source, to any destination, of
                          # any allowed kind. Every list is written out, none has a default.
                          incomingRule = let
                            portNumber = ints.between 1 65535;

                            portRange = submodule {
                              options = {
                                from = mkOption {
                                  type = portNumber;
                                  description = "First port of the range.";
                                };
                                to = mkOption {
                                  type = portNumber;
                                  description = "Last port of the range, included. Not below `from`.";
                                };
                              };
                            };

                            allowedTraffic = submodule {
                              options = {
                                protocol = mkOption {
                                  type = enum ["tcp" "udp" "sctp" "icmpv6"];
                                  description = "Protocol of the allowed traffic.";
                                };
                                ports = mkOption {
                                  type = listOf (either portNumber portRange);
                                  default = [];
                                  example = literalExpression ''
                                    [ 80 443 { from = 8000; to = 8080; } ]
                                  '';
                                  description = ''
                                    Destination ports, as numbers or `{ from; to; }` ranges.
                                    Required for `tcp`, `udp` and `sctp`, and an error for
                                    `icmpv6`, which has no ports.
                                  '';
                                };
                              };
                            };
                          in
                            submodule {
                              options = {
                                sourceAddresses = mkOption {
                                  # Address first: a bare address is not valid CIDR, so trying the
                                  # network type first would throw instead of falling through.
                                  type = nonEmptyListOf (either (singleHostWithin null) (networkWith {version = 6;}));
                                  apply = map (source:
                                    if ip.isAddress source
                                    then ip.address.getNetwork source
                                    else source);
                                  example = ["::/0" "fd00:1:2:3::10"];
                                  description = ''
                                    Where the traffic may come from: IPv6 single-host addresses
                                    or networks, as `lib.extra.ip` data or text. They read back
                                    as networks, a single host as its /128. Name remote
                                    containers through their hosts'
                                    `services.sigil.settings.containers`.
                                  '';
                                };

                                destinationAddresses = mkOption {
                                  type = nonEmptyListOf (singleHostWithin null);
                                  example = literalExpression ''
                                    with config.services.sigil.settings.containers.<group>.<uuid>.addresses.ipv6;
                                      [ extra.gua.ssh ]
                                  '';
                                  description = ''
                                    Which of the container's own addresses the traffic may reach.
                                    An address the container does not hold is an error.
                                  '';
                                };

                                allowedTraffic = mkOption {
                                  type = nonEmptyListOf allowedTraffic;
                                  example = literalExpression ''
                                    [ { protocol = "tcp"; ports = [ 22 ]; } { protocol = "icmpv6"; } ]
                                  '';
                                  description = "What traffic is allowed, by protocol and destination port.";
                                };
                              };
                            };
                        in {
                          incoming = mkOption {
                            type = listOf incomingRule;
                            default = [];
                            example = literalExpression ''
                              [
                                {
                                  sourceAddresses = [ "::/0" ];
                                  destinationAddresses = [ config.services.sigil.settings.containers.<group>.<uuid>.addresses.ipv6.extra.gua.ssh ];
                                  allowedTraffic = [ { protocol = "tcp"; ports = [ 22 ]; } ];
                                }
                              ]
                            '';
                            description = ''
                              Traffic this container accepts, as rules of sources,
                              destinations and allowed traffic. A packet is accepted
                              when one rule matches its source, its destination and
                              its protocol and port.

                              The host checks traffic it forwards to the container
                              against these rules. Until
                              `settings.network.enforceTrafficRules` is set, traffic
                              no rule allows is counted and forwarded anyway.
                              Traffic the host itself sends to the container is not
                              forwarded, so these rules do not cover it on the host.
                            '';
                          };
                        };
                      };

                      group = mkOption {
                        type = str;
                        default = group;
                        defaultText = literalExpression "group";
                        description = ''
                          Group this container belongs to. Determines the ULA /64
                          prefix its address is derived from.
                        '';
                      };

                      mid = mkOption {
                        type = str;
                        default = name;
                        defaultText = literalExpression "name";
                        description = ''
                          Container identity. Must be a valid UUID: it is passed
                          verbatim to `systemd-nspawn --uuid=` and seeds the
                          container's interface identifier.
                        '';
                      };

                      nspawn = {
                        settings = mkOption {
                          inherit ((options.systemd.nspawn.type.getSubOptions []).settings) type;
                          default = {};
                          description = "Nspawn configuration (same as `systemd.nspawn.settings`).";
                        };
                        flags = mkOption {
                          type = listOf str;
                          default = [];
                          example = ["--drop-capability=CAP_SYS_CHROOT"];
                          description = ''
                            Flags passed to the systemd-nspawn command.
                            See {manpage}`systemd-nspawn(1)` for details.
                          '';
                        };
                      };

                      modules = mkOption {
                        type = listOf deferredModule;
                        default = [];
                        description = ''
                          NixOS modules of this container, evaluated together with
                          the shared module set.
                        '';
                      };

                      evaluation = mkOption {
                        type = lib.types.unspecified;
                        readOnly = true;
                        default = import "${toString pkgs.path}/nixos/lib/eval-config.nix" {
                          prefix = ["sigil" "containers" config.group config.mid];
                          system = null;

                          modules =
                            config.modules
                            ++ recursive ./_container
                            ++ (recursive (self + "/nix/modules/nixos"))
                            ++ [
                              (_: {
                                imports = singleton (modulesPath + "/misc/nixpkgs/read-only.nix");

                                config = {
                                  nixpkgs = {
                                    inherit pkgs;
                                  };
                                };
                              })
                            ];

                          specialArgs = {
                            hostConfig = host.config;

                            hostName = config.mid;

                            sigil = {
                              self = infosFor config;
                              containers =
                                mapAttrs (_: mapAttrs (_: infosFor)) cfg.settings.containers;
                              inherit linkLocal;
                            };

                            inherit lib self;
                          };
                        };
                      };
                    };

                    config = {
                      nspawn = {
                        # No flags are a requirement for sigil to work correctly, but
                        # having a stable machine id can improve debugging experience.
                        flags = mkBefore [
                          "--settings=trusted"
                          "--keep-unit"
                          "--quiet"
                          # If you decide to use systemd credentials for services inside the container
                          # then having a stable machine id is a must, as host-key based encryption
                          # ties generated credential.secret to a machine id (tpm2 would require a
                          # bind mount and a device passthrough). If your machine id changes, then
                          # your credential.secret WILL BE DELETED when a decryption by any service
                          # is attempted WITHOUT A WARNING.
                          "--uuid=${config.mid}"
                          "--machine=${config.mid}"
                        ];
                      };
                    };
                  }
                );
          in
            attrsOf (
              submodule ({name, ...}: {
                freeformType = attrsOf (containerModule name);
              })
            );

          # Container values coerce to their MID.
          apply = mapAttrs (
            _group:
              mapAttrs (
                _: container:
                  container
                  // {
                    __toString = self: self.mid;
                  }
              )
          );

          default = {};
          description = ''
            Declarative systemd-nspawn containers, keyed by group and
            then by container UUID.
          '';
        };

        network = {
          links = mkOption {
            type = let
              linkModule = let
                getBIdentity = a: b:
                  substring 0 12 (hashString "sha256"
                    (concatStringsSep ":" (sort (x: y: x < y) [a b])));

                getPIdentity = a: b: substring 0 12 (hashString "sha256" "${a}:${b}");
              in
                group: source:
                  submodule (
                    {config, ...}: {
                      options = {
                        source = lib.mkOption {
                          type = str;
                          readOnly = true;
                          apply = mid: attrByPath [mid] null cfg.settings.containers.${group};
                          default = source;
                        };

                        target = mkOption {
                          type = attrsOf raw;
                          description = "Target container. Must be a container's UUID.";
                        };

                        bid = mkOption {
                          type = str;
                          readOnly = true;
                          default = getBIdentity config.source.mid config.target.mid; # direction-free: sorted before hashing
                          defaultText = literalExpression "mkBID <source> config.target";
                          description = "Bridge id — identical for a→b and b→a.";
                        };

                        pid = mkOption {
                          type = str;
                          readOnly = true;
                          default = getPIdentity config.source.mid config.target.mid; # directional
                          defaultText = literalExpression "mkPID <source> config.target";
                          description = "Policy id — distinct per direction.";
                        };
                      };
                    }
                  );

              linksList = mkOptionType {
                name = "listOfLinks";
                description = "list of links";
                merge = loc: defs: let
                  n = length loc;
                  source = elemAt loc (n - 1);
                  group = elemAt loc (n - 2);
                in
                  (listOf (linkModule group source)).merge loc defs;
                getSubOptions = prefix:
                  (listOf (linkModule "<group>" "<source>")).getSubOptions prefix;
              };
            in
              attrsOf (attrsOf linksList);

            default = {};
            example = literalExpression ''
              {
                intra.''${mid} = [
                  { target = config.services.sigil.settings.containers.intra."fd0cac8e-…"; }
                ];
              }
            '';
            description = ''
              Linked peers per container, keyed by group and then by
              container UUID, mirroring `settings.containers`.
              Elements are container definitions taken directly from
              `settings.containers.<group>.<uuid>`. They reach the
              container's modules through `sigil.self.links`, where each
              bridge's `port` is the peer container (its `mid`,
              `addresses.ipv6`, …); host-side enforcement
              (routes/firewall) is still open.
            '';
          };
          hostAddress = mkOption {
            type = singleHostWithin ip.ranges.ipv6.uniqueLocal;
            example = "fd00:1:2::1";
            description = ''
              The host's own address on the internal network: a single
              host within fc00::/7, as `lib.extra.ip` address data (/128).
              The host-side routes toward containers' unique local
              addresses prefer it as source address (`PreferredSource=`).

              It may lie outside `ula.prefix`. Inside it, it must stay out
              of every group /64, as those belong to the containers.
              sigil does not assign it to an interface.

              Replaces `ula.source`, which still works as a deprecated
              alias.
            '';
          };
          # ──────────────────────────────────────────────────────────────────
          # TODO: Remove once hosts have moved over, enforcing always.
          # ──────────────────────────────────────────────────────────────────
          enforceTrafficRules = mkOption {
            type = bool;
            default = false;
            description = ''
              Whether the host drops forwarded traffic to containers that
              no traffic rule allows. When false, such traffic is counted
              (counters `undeclared-incoming` and `invalid-incoming` in the
              nftables table `inet sigil`) and forwarded as before.

              Temporary: once every host has moved over, the rules are
              always enforced and this option is removed.
            '';
          };
          gua = {
            prefix = mkOption {
              type = nullOr (networkWith {
                version = 6;
                within = ip.ranges.ipv6.globalUnicast;
                prefixLength = 64;
              });
              default = null;
              example = "2001:db8:1:2::/64";
              description = ''
                A /64 GUA prefix managed by the host, within 2000::/3. Given as
                CIDR or as its four groups (`"2001:db8:1:2"`). Containers' GUAs
                are host parts on it. When null, containers get no globally
                routable address and are reachable only via ULA.
              '';
            };
          };
          ula = {
            prefix = mkOption {
              type = networkWith {
                version = 6;
                within = ip.ranges.ipv6.uniqueLocal;
                prefixLength = 48;
              };
              example = "fd00:1:2::/48";
              description = ''
                A /48 ULA prefix managed by the host, within fc00::/7. Given as
                CIDR or as its three groups (`"fd00:1:2"`). Each group of
                containers gets one /64 of it.
              '';
            };
          };
        };
      };
    };
  };

  config = let
    inherit (lib.extra) ip;
    inherit (lib.attrsets) attrValues filterAttrs mapAttrsToList mergeAttrsList;
    inherit (lib.lists) all concatLists concatMap elem filter foldl' groupBy imap0 length optional singleton unique;
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.strings) concatStringsSep;
  in let
    # Flat container list, evaluating each container
    # exactly once and carrying the result along.
    containers = rec {
      all =
        concatLists
        (mapAttrsToList (
            _:
              mapAttrsToList (
                _: container: container
              )
          )
          cfg.settings.containers);

      lib = {
        # f :: container -> attrset; results merged into one attrset
        mapToAttrs = f: mergeAttrsList (map f all);

        # f :: container -> list; results concatenated into one list
        mapToList = f: concatMap f all;
      };
    };
  in let
    links = rec {
      collected = cfg.settings.network.links;
      policies = concatLists (concatMap attrValues (attrValues collected));
      bridges = attrValues (foldl' (acc: link:
        if acc ? ${link.bid}
        then acc
        else
          acc
          // {
            ${link.bid} = {
              inherit (link) bid;
              ports = [
                link.source
                link.target
              ];
            };
          }) {}
      policies);

      lib = {
        bridge = {
          mapToAttrs = f: mergeAttrsList (map f bridges);
          mapToList = f: concatMap f bridges;
        };
        policy = {
          mapToAttrs = f: mergeAttrsList (map f policies);
          mapToList = f: concatMap f policies;
        };
      };
    };
  in
    mkIf cfg.enable (mkMerge [
      (
        mkIf (cfg.settings.containers != {}) (
          mkMerge [
            {
              assertions = let
                # Every address a container holds, labelled with the option it
                # comes from (relative to addresses.ipv6).
                addressEntries = container: let
                  inherit (container.addresses.ipv6) ula gua extra;
                  unresolvable = container.addressesWithoutPrefix;
                  named = kind:
                    mapAttrsToList (name: address: {
                      label = "extra.${kind}.${name}";
                      inherit address;
                    });
                in
                  (
                    [
                      {
                        label = "ula";
                        address = ula;
                      }
                    ]
                    # Skip a GUA that cannot be resolved.
                    ++ optional (!(elem "gua" unresolvable) && gua != null) {
                      label = "gua";
                      address = gua;
                    }
                    ++ named "ula" extra.ula
                    ++ named "gua" extra.gua
                  )
                  # Labels are checked without touching the addresses, so
                  # unresolvable extras are never forced.
                  |> filter (entry: !(elem entry.label unresolvable))
                  |> map (entry: entry // {container = "${container.group}/${container.mid}";});

                entries = containers.lib.mapToList addressEntries;

                # The same address held twice would get conflicting /128 host
                # routes. All addresses are /128 data, so grouping by canonical
                # text is the same as comparing the data.
                clashes =
                  entries
                  |> groupBy (entry: ip.toCompressed entry.address)
                  |> filterAttrs (_: holders: length holders > 1);

                describeClash = address: entries: "  ${address}: ${concatStringsSep ", " (entries |> map (entry: "${entry.container} (${entry.label})"))}";

                describeContainer = container: label: "${container.group}/${container.mid} (${label})";

                # Host parts set although their prefix is missing.
                withoutPrefix =
                  containers.lib.mapToList (container:
                    map (describeContainer container) container.addressesWithoutPrefix);

                # The /64 an address lies in.
                subnetOf = address: ip.address.getNetwork (ip.address.withPrefixLength 64 address);

                # The all-zero host part is the subnet-router anycast address:
                # an address equal to the network address of its /64.
                isSubnetRouterAnycast = address:
                  ip.toCompressed address == ip.toCompressed (subnetOf address);

                # Groups whose /64 holds the host address. Every group /64
                # lies in the ULA /48, so an address outside it never clashes.
                groupsHoldingHostAddress =
                  containers.all
                  |> filter (container: ip.network.contains (subnetOf container.addresses.ipv6.ula) cfg.settings.network.hostAddress)
                  |> map (container: container.group)
                  |> unique;

                subnetRouterAnycast =
                  entries
                  |> filter (entry: isSubnetRouterAnycast entry.address)
                  |> map (entry: "${entry.container} (${entry.label})");

                # A container's incoming rules, each labelled with its position.
                incomingRules = container:
                  container.rules.networkTraffic.incoming
                  |> imap0 (index: rule: rule // {label = "${container.group}/${container.mid} rules.networkTraffic.incoming.${toString index}";});

                # Destinations the container does not hold. Its own addresses
                # come from addressEntries, which skips unresolvable ones.
                foreignDestinations = containers.lib.mapToList (container: let
                  own = addressEntries container |> map (entry: ip.toCompressed entry.address);
                in
                  incomingRules container
                  |> concatMap (rule:
                    rule.destinationAddresses
                    |> filter (address: !(elem (ip.toCompressed address) own))
                    |> map (address: "  ${rule.label}: ${ip.toCompressed address}")));

                # Missing ports where the protocol has them, ports where it has
                # none, and ranges that run backwards.
                portErrors = containers.lib.mapToList (container:
                  incomingRules container
                  |> concatMap (rule:
                    rule.allowedTraffic
                    |> imap0 (index: traffic: let
                      where = "  ${rule.label}.allowedTraffic.${toString index} (${traffic.protocol})";
                      hasPorts = traffic.protocol != "icmpv6";
                      backwards = traffic.ports |> filter (port: builtins.isAttrs port && port.from > port.to);
                    in
                      optional (hasPorts && traffic.ports == []) "${where}: needs ports"
                      ++ optional (!hasPorts && traffic.ports != []) "${where}: takes no ports"
                      ++ map (range: "${where}: range ${toString range.from}-${toString range.to} runs backwards") backwards)
                    |> concatLists));
              in [
                {
                  assertion = let
                    mids = map (container: container.mid) containers.all;
                  in
                    builtins.length (unique mids) == builtins.length mids;
                  message = "sigil: Machine ID (MID) used by more than one container";
                }
                {
                  assertion = all (c: builtins.match "[0-9a-f-]{36}" c.mid != null) containers.all;
                  message = "sigil: Machine ID (MID) must be a UUID (passed to --uuid=)";
                }
                {
                  assertion = withoutPrefix == [];
                  message = "sigil: settings.network.gua.prefix is not set, but GUA host parts are: ${concatStringsSep ", " withoutPrefix}";
                }
                {
                  assertion = subnetRouterAnycast == [];
                  message = "sigil: host part :: is the subnet-router anycast address and cannot be a container address: ${concatStringsSep ", " subnetRouterAnycast}";
                }
                {
                  assertion = groupsHoldingHostAddress == [];
                  message = "sigil: settings.network.hostAddress ${ip.toCompressed cfg.settings.network.hostAddress} lies in the /64 of group ${concatStringsSep ", " groupsHoldingHostAddress}, which belongs to its containers";
                }
                {
                  assertion = clashes == {};
                  message = concatStringsSep "\n" (["sigil: addresses held more than once:"] ++ mapAttrsToList describeClash clashes);
                }
                {
                  assertion = foreignDestinations == [];
                  message = concatStringsSep "\n" (["sigil: traffic rules name destinations their container does not hold:"] ++ foreignDestinations);
                }
                {
                  assertion = portErrors == [];
                  message = concatStringsSep "\n" (["sigil: traffic rules with invalid ports:"] ++ portErrors);
                }
                {
                  assertion = config.networking.nftables.enable;
                  message = "sigil: source validation runs on nftables, but networking.nftables.enable is not set";
                }
              ];
            }
            {
              systemd = {
                network = {
                  config = {
                    networkConfig = {
                      IPv6Forwarding = true;
                    };
                  };
                };
              };
            }
            {
              # SYSTEMD SERVICE
              # ---------------
              systemd = let
                systemd-nspawn.service.name = mid: "systemd-nspawn@${mid}";
              in {
                services = containers.lib.mapToAttrs (container: {
                  ${systemd-nspawn.service.name container.mid} = {
                    overrideStrategy = "asDropin";
                    restartTriggers = [
                      # Changes to Container Configuration
                      (builtins.toJSON container.evaluation.config.system.build.toplevel)
                      # Changes to Container's Nspawn Unit
                      (builtins.toJSON globalConfig.systemd.nspawn.${container.mid})
                    ];
                    serviceConfig = {
                      ExecStart = [
                        ""
                        (builtins.concatStringsSep " " ((singleton "systemd-nspawn") ++ container.nspawn.flags))
                      ];
                    };
                  };
                });

                targets = {
                  machines = {
                    wants = containers.lib.mapToList (container: [
                      "${systemd-nspawn.service.name container.mid}.service"
                    ]);
                  };
                };

                tmpfiles = {
                  settings = containers.lib.mapToAttrs (container: {
                    "10-systemd-nspawn-${container.mid}" = {
                      "/var/lib/machines/${container.mid}/usr".d = {
                        user = "524288";
                        group = "524288";
                      };
                    };
                  });
                };
              };
            }
            {
              # NSPAWN CONFIG
              # -------------
              systemd = {
                nspawn = containers.lib.mapToAttrs (container: {
                  ${container.mid} = {
                    settings = mkMerge [
                      container.nspawn.settings
                      {
                        Exec = {
                          PrivateUsers = "pick";
                          LinkJournal = "try-host";
                          Parameters = "${container.evaluation.config.system.build.toplevel}/init";
                          Ephemeral = true;
                          Timezone = "off";
                          Boot = false;
                          KillSignal = "SIGRTMIN+3";
                        };
                        Files = {
                          PrivateUsersOwnership = "chown";
                          BindReadOnly = [
                            "/nix/store:/nix/store:idmap"
                          ];
                        };
                        Network = {
                          Private = true;
                          VirtualEthernet = true;
                        };
                      }
                    ];
                  };
                });
              };
            }
            {
              # NETWORK CONFIG
              # --------------
              systemd = let
                systemd-nspawn.ve.altname = mid: "ve-${mid}";
              in {
                network = {
                  networks = containers.lib.mapToAttrs (container: {
                    "10-${systemd-nspawn.ve.altname container.mid}" = {
                      networkConfig = {
                        IPv6LinkLocalAddressGenerationMode = "none";
                      };
                      matchConfig = {
                        Name = systemd-nspawn.ve.altname container.mid;
                        Kind = "veth";
                      };
                      addresses = [
                        {
                          Address = linkLocal.host |> ip.toCIDR;
                        }
                      ];
                      # Container addresses are /128 by type, so toCIDR yields host routes.
                      routes = let
                        inherit (container.addresses.ipv6) ula gua extra;

                        guaRoute = address: {
                          Destination = address |> ip.toCIDR;
                          Gateway = linkLocal.container |> ip.toCompressed;
                          GatewayOnLink = true;
                        };

                        ulaRoute = address:
                          guaRoute address
                          // {
                            PreferredSource = cfg.settings.network.hostAddress |> ip.toCompressed;
                          };
                      in
                        optional (gua != null) (guaRoute gua)
                        ++ [(ulaRoute ula)]
                        ++ map guaRoute (attrValues extra.gua)
                        ++ map ulaRoute (attrValues extra.ula);
                    };
                  });
                };
              };
            }
            {
              # SOURCE VALIDATION
              # -----------------
              # Container addresses are accepted only from their own veth. Always
              # on: it drops only forged traffic, so both counters stay at zero.
              # Runs at priority raw, before conntrack and the routing decision,
              # so forged packets never reach the host's or containers' rules.
              #
              # A route lookup on the source address must lead back out the
              # interface the packet came in on (strict reverse path), which
              # needs no interface names: nspawn shortens `ve-<mid>` with a hash.
              networking.nftables.tables.sigil = {
                family = "inet";
                content = let
                  # Each address on its own (/128): the /48 may be shared with
                  # other hosts, whose containers arrive over the overlay.
                  addresses =
                    containers.lib.mapToList (container: let
                      inherit (container.addresses.ipv6) ula gua extra;
                    in
                      [ula]
                      ++ optional (gua != null) gua
                      ++ attrValues extra.ula
                      ++ attrValues extra.gua)
                    |> map ip.toCompressed;
                in ''
                  counter forged-on-veth {
                    comment "from a container's veth, with a source address that is not the container's"
                  }

                  counter forged-container-address {
                    comment "with a container's source address, from anywhere but its veth"
                  }

                  set container-addresses {
                    type ipv6_addr
                    elements = { ${concatStringsSep ", " addresses} }
                  }

                  chain validate-source {
                    type filter hook prerouting priority raw; policy accept;

                    # Duplicate address detection and MLD, sent before the
                    # container's link-local address is in use.
                    iifname "ve-*" ip6 saddr :: icmpv6 type { nd-neighbor-solicit, mld-listener-report, mld2-listener-report } accept

                    # From a container: its own addresses or link-local only.
                    # Containers have no IPv4, so all IPv4 is dropped here too.
                    iifname "ve-*" fib saddr . iif oif missing counter name forged-on-veth drop

                    # To a container's address: only through its own veth.
                    ip6 saddr @container-addresses fib saddr . iif oif missing counter name forged-container-address drop
                  }
                '';
              };
            }
            {
              # HOST FILTERING
              # --------------
              # Forwarded traffic to container addresses must be allowed by a
              # traffic rule of the container holding the destination. Until
              # enforceTrafficRules is set, the last two rules count and accept,
              # so the host forwards exactly what it did before. Shares the
              # `inet sigil` table with source validation.
              networking.nftables.tables.sigil.content = let
                verdict =
                  if cfg.settings.network.enforceTrafficRules
                  then "drop"
                  else "accept";

                # nft merges duplicate and overlapping elements of a set.
                setOf = elements: "{ ${concatStringsSep ", " elements} }";

                portText = port:
                  if builtins.isAttrs port
                  then "${toString port.from}-${toString port.to}"
                  else toString port;

                # A source list holding ::/0 matches anything, so it needs no match.
                matchSources = sources: let
                  cidrs = map ip.toCIDR sources;
                in
                  if elem "::/0" cidrs
                  then ""
                  else "ip6 saddr ${setOf cidrs} ";

                matchTraffic = traffic:
                  if traffic.protocol == "icmpv6"
                  then "meta l4proto ipv6-icmp"
                  else "${traffic.protocol} dport ${setOf (map portText traffic.ports)}";

                # One counted accept per allowed traffic of each rule, labelled
                # with its place in the container's rules.
                ruleLines = container:
                  container.rules.networkTraffic.incoming
                  |> imap0 (ruleIndex: rule:
                    rule.allowedTraffic
                    |> imap0 (trafficIndex: traffic:
                      matchSources rule.sourceAddresses
                      + "ip6 daddr ${setOf (map ip.toCompressed rule.destinationAddresses)} "
                      + "${matchTraffic traffic} counter accept "
                      + ''comment "${container.group}/${container.mid} incoming.${toString ruleIndex}.allowedTraffic.${toString trafficIndex}"''))
                  |> concatLists;
              in ''
                counter undeclared-incoming {
                  comment "forwarded to a container, allowed by no traffic rule"
                }

                counter invalid-incoming {
                  comment "forwarded to a container, belonging to no known connection"
                }

                chain filter-incoming {
                  type filter hook forward priority filter; policy accept;

                  # Not for a container: left to the host's other rules.
                  ip6 daddr != @container-addresses accept

                  # Replies to allowed connections, and their ICMPv6 errors.
                  ct state established,related accept
                  ct state invalid counter name invalid-incoming ${verdict}

                  # ICMPv6 errors that IPv6 needs to work (path MTU among them).
                  icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem } accept

                  ${concatStringsSep "\n  " (containers.lib.mapToList ruleLines)}

                  counter name undeclared-incoming ${verdict}
                }
              '';
            }
          ]
        )
      )
      (
        mkIf (cfg.settings.network.links != {})
        (mkMerge [
          {
            assertions = [
              {
                assertion = all (e: e.source != e.target) links.policies;
                message = "sigil: container declares a link to itself";
              }
              {
                assertion = builtins.length (unique (map (e: e.bid) links.bridges)) == builtins.length links.bridges;
                message = "sigil: Bridge ID (BID) collision — widen getBIdentity substring";
              }
            ];
          }
          {
            # NSPAWN CONFIG
            # -------------
            systemd.nspawn = let
              inherit (lib.lists) concatMap foldl';

              # one {mid, extra} record per (bridge, port)
              entries =
                concatMap (
                  bridge:
                    map (port: {
                      inherit (port) mid;
                      extra = "${mkLHLinkName bridge.bid port.mid}:${mkLCLinkName bridge.bid port.mid}";
                    })
                    bridge.ports
                )
                links.bridges;

              # fold into { <mid> = { settings.Network.VirtualEthernetExtra = [ … all its links … ]; }; }
              byMID = foldl' (acc: e:
                acc
                // {
                  ${e.mid} = {
                    settings = {
                      Network = {
                        VirtualEthernetExtra = (acc.${e.mid}.settings.Network.VirtualEthernetExtra or []) ++ [e.extra];
                      };
                    };
                  };
                }) {}
              entries;
            in
              byMID;
          }
          {
            # NETWORK CONFIG
            # --------------
            systemd = {
              network = {
                netdevs = links.lib.bridge.mapToAttrs (bridge: let
                  Name = mkBridgeName bridge.bid;
                in {
                  "10-${Name}" = {
                    netdevConfig = {
                      inherit Name;
                      Kind = "bridge";
                    };
                  };
                });
                networks =
                  (
                    links.lib.bridge.mapToAttrs (bridge:
                      mergeAttrsList (map (port: let
                          Name = mkLHLinkName bridge.bid port.mid;
                        in {
                          "10-${Name}" = {
                            matchConfig = {
                              inherit Name;
                            };
                            networkConfig = {
                              Bridge = mkBridgeName bridge.bid;
                              LinkLocalAddressing = "no";
                            };
                          };
                        })
                        bridge.ports))
                  )
                  // (
                    links.lib.bridge.mapToAttrs (bridge: let
                      Name = mkBridgeName bridge.bid;
                    in {
                      "10-${Name}" = {
                        matchConfig = {
                          inherit Name;
                        };
                        networkConfig = {
                          LinkLocalAddressing = "no";
                          ConfigureWithoutCarrier = true;
                        };
                        linkConfig.RequiredForOnline = false;
                      };
                    })
                  );
              };
            };
          }
        ])
      )
    ]);
}
