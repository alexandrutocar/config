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
    inherit (lib.attrsets) attrByPath attrValues mapAttrs mergeAttrsList;
    inherit (lib.lists) any concatMap elemAt foldl' length optional singleton sort;
    inherit (lib.modules) mkBefore;
    inherit (lib.options) literalExpression mkEnableOption mkOption;
    inherit (lib.types) attrsOf deferredModule listOf mkOptionType nullOr raw str submodule;
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
                            apply = hostPart: let
                              prefix = cfg.settings.network.gua.prefix;
                            in
                              if hostPart == null
                              then null
                              else if prefix == null
                              then throw "sigil: ${config.group}/${config.mid} sets addresses.ipv6.gua, but settings.network.gua.prefix is not set"
                              else ip.address.singleHostRoute (ip.network.hostAddress prefix hostPart);
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
                            '';
                          };

                          ula = mkOption {
                            type = singleHostWithin ip.ranges.ipv6.uniqueLocal;
                            readOnly = true;
                            default = getHostAddress (getULASubnet cfg.settings.network.ula.prefix config.group) config.mid;
                            defaultText = literalExpression ''
                              <ula prefix>:<subnet>:<iid>/128
                              # <subnet>: first 4 hex digits of sha256(group)
                              # <iid>: first 16 hex digits of sha256(mid)
                            '';
                            description = ''
                              The container's identity on the internal network: a
                              zone-local address derived from its group and MID, as
                              `lib.extra.ip` address data (/128, within fc00::/7).
                              Always present and read-only, so it stays unique across
                              hosts without coordination; a container's ULA changes
                              only with its group or MID.
                              Render with `lib.extra.ip.toCompressed` or `toCIDR`.
                            '';
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
                        default = optional (
                          cfg.settings.network.gua.prefix
                          == null
                          && any (hostPart: hostPart != null) containerArgs.options.addresses.ipv6.gua.definitions
                        ) "gua";
                        description = ''
                          Labels (relative to `addresses.ipv6`) of host parts this
                          container sets although their prefix is not configured.
                          Collected by an assertion that lists every such container.
                        '';
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
            _zone:
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
            Declarative systemd-nspawn containers, keyed by zone and
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
            source = mkOption {
              type = singleHostWithin ip.ranges.ipv6.uniqueLocal;
              example = "fd00:1:2::1";
              description = ''
                `PreferredSource=` for the host-side ULA route toward
                each container: the host's own ULA address (a single host
                within fc00::/7).
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
    inherit (lib.lists) all concatLists concatMap elem foldl' groupBy length optional singleton unique;
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
                addressEntries = container:
                  (
                    [
                      {
                        label = "ula";
                        address = container.addresses.ipv6.ula;
                      }
                    ]
                    # Skip a GUA that cannot be resolved.
                    ++ optional (!(elem "gua" container.addressesWithoutPrefix) && container.addresses.ipv6.gua != null) {
                      label = "gua";
                      address = container.addresses.ipv6.gua;
                    }
                  )
                  |> map (entry: entry // {container = "${container.group}/${container.mid}";});

                # The same address held twice would get conflicting /128 host
                # routes. All addresses are /128 data, so grouping by canonical
                # text is the same as comparing the data.
                clashes =
                  containers.lib.mapToList addressEntries
                  |> groupBy (entry: ip.toCompressed entry.address)
                  |> filterAttrs (_: entries: length entries > 1);

                describeClash = address: entries: "  ${address}: ${concatStringsSep ", " (entries |> map (entry: "${entry.container} (${entry.label})"))}";

                describeContainer = container: label: "${container.group}/${container.mid} (${label})";

                # Host parts set although their prefix is missing.
                withoutPrefix =
                  containers.lib.mapToList (container:
                    map (describeContainer container) container.addressesWithoutPrefix);

                # The all-zero host part is the subnet-router anycast address.
                subnetRouterAnycast = containers.lib.mapToList (container: let
                  inherit (container.addresses.ipv6) gua;
                in
                  optional (
                    container.addressesWithoutPrefix
                    == []
                    && gua != null
                    && ip.toCompressed gua == ip.toCompressed (ip.network.getNetworkAddress cfg.settings.network.gua.prefix)
                  ) (describeContainer container "gua"));
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
                  assertion = clashes == {};
                  message = concatStringsSep "\n" (["sigil: addresses held more than once:"] ++ mapAttrsToList describeClash clashes);
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
                      "${systemd-nspawn.service.name container}.service"
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
                      routes =
                        optional (container.addresses.ipv6.gua != null) {
                          Destination = container.addresses.ipv6.gua |> ip.toCIDR;
                          Gateway = linkLocal.container |> ip.toCompressed;
                          GatewayOnLink = true;
                        }
                        ++ [
                          {
                            Destination = container.addresses.ipv6.ula |> ip.toCIDR;
                            Gateway = linkLocal.container |> ip.toCompressed;
                            GatewayOnLink = true;
                            PreferredSource = cfg.settings.network.ula.source |> ip.toCompressed;
                          }
                        ];
                    };
                  });
                };
              };
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
