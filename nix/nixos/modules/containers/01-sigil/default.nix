{
  modulesPath,
  options,
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  globalConfig = config;
  cfg = config.services.sigil;
in let
  mkBridgeName = bid: "br-${bid}";
  mkLHLinkName = bid: mid: "lh-${builtins.substring 0 12 (builtins.hashString "sha256" (bid + mid))}";
  mkLCLinkName = bid: mid: "lc-${builtins.substring 0 12 (builtins.hashString "sha256" (bid + mid))}";
in {
  options = let
    inherit (lib) hashString;
    inherit (lib.extra.files.list) recursive;
    inherit (lib.attrsets) attrByPath attrValues mapAttrs mergeAttrsList;
    inherit (lib.lists) concatMap elemAt foldl' length sort;
    inherit (lib.modules) mkBefore;
    inherit (lib.options) literalExpression mkEnableOption mkOption;
    inherit (lib.types) attrsOf deferredModule listOf mkOptionType nullOr raw str submodule;
    inherit (lib.strings) concatStringsSep substring;
  in {
    services.sigil = {
      enable = mkEnableOption "sigil";

      settings = {
        containers = mkOption {
          type = let
            # A single container, parameterized over the zone it is declared in.
            # `id` defaults to the attribute name and `zone` to the enclosing
            # attribute, so `inherit id zone;` at the call site is optional.
            containerModule = let
              # Stable 64-bit interface identifier derived from the container id.
              getIIdentity = mid: let
                hash = hashString "sha256" mid;
              in
                concatStringsSep ":" [
                  (substring 0 4 hash)
                  (substring 4 4 hash)
                  (substring 8 4 hash)
                  (substring 12 4 hash)
                ];

              # GUA ADDRESS DERIVATION
              # ----------------------
              getGUAddress = prefix: mid: "${prefix}:${getIIdentity mid}";

              # ULA ADDRESS DERIVATION
              # ----------------------
              getULAPrefix = prefix: group: let
                hash = builtins.hashString "sha256" group;
              in "${prefix}:${builtins.substring 0 4 hash}";

              getULAddress = prefix: group: mid: "${getULAPrefix prefix group}:${getIIdentity mid}";
            in
              group:
                submodule (
                  {
                    config,
                    name,
                    ...
                  }: {
                    options = let
                      # EVALUATION
                      # ----------
                      # Address book handed to the container's own module system through
                      # `specialArgs.container`.
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
                        gua = mkOption {
                          readOnly = false;
                          type = nullOr str;
                          default = getGUAddress cfg.settings.network.gua.prefix config.mid;
                          description = "Globally routable address of the container.";
                        };

                        ula = mkOption {
                          readOnly = false;
                          type = nullOr str;
                          default = getULAddress cfg.settings.network.ula.prefix config.group config.mid;
                          description = "Zone-local address of the container.";
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
                        config = mkOption {
                          type = options.systemd.nspawn.type.nestedTypes.elemType;
                          default = {};
                          description = "Nspawn configuration `systemd.nspawn.<name>`.";
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
                            ++ [
                              (_: {
                                imports = [
                                  (modulesPath + "/misc/nixpkgs/read-only.nix")
                                  (self + "/nix/nixos")
                                ];
                                config = {
                                  nixpkgs = {
                                    inherit pkgs;
                                  };
                                  system = {
                                    stateVersion = "26.05";
                                  };
                                };
                              })
                            ];

                          specialArgs = {
                            sigil = {
                              self = infosFor config;
                              containers =
                                mapAttrs (_: mapAttrs (_: infosFor)) cfg.settings.containers;
                            };
                            inherit lib;
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
              Linked peers per container, keyed by zone and then by
              container UUID, mirroring `settings.containers`.
              Elements are container definitions taken directly from
              `settings.containers.<zone>.<uuid>`. They are flattened
              to plain data (id, zone, machine, gua, ula) before
              reaching the container's modules as
              `container.network.links`; host-side enforcement
              (routes/firewall) is still open.
            '';
          };
          gua = {
            prefix = mkOption {
              type = str;
              description = ''
                A ::/64 GUA prefix managed by the host.
              '';
            };
          };
          ula = {
            prefix = mkOption {
              type = str;
              description = ''
                An ::/48 ULA prefix managed by the host.
              '';
            };
            source = mkOption {
              type = str;
              description = ''
                `PreferredSource=` for the host-side ULA route toward
                each container (the host's own ULA address). The default
                carries over the previously hard-coded value; derive or
                override it as appropriate.
              '';
            };
          };
        };
      };
    };
  };

  config = let
    inherit (lib.attrsets) attrValues mapAttrsToList mergeAttrsList;
    inherit (lib.generators) toJSON;
    inherit (lib.lists) all concatLists concatMap foldl' optional singleton unique;
    inherit (lib.modules) mkIf mkMerge;
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
      collected = let
        value = cfg.settings.network.links;
      in
        builtins.trace "All Links: \n${toJSON {} value}" value;
      policies = let
        value = concatLists (concatMap attrValues (attrValues collected));
      in
        builtins.trace "All Policies: \n${toJSON {} value}" value;
      bridges = let
        value = attrValues (foldl' (acc: link:
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
      in
        builtins.trace "All Bridges: \n${toJSON {} value}" value;

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
              assertions = [
                {
                  assertion = let
                    ulas.all = map (container: container.mid) containers.all;
                  in
                    builtins.length (unique ulas.all) == builtins.length ulas.all;
                  message = "sigil: Unique Local Address (ULA) collision — duplicate machine-id?";
                }
                {
                  assertion = all (c: builtins.match "[0-9a-f-]{36}" c.mid != null) containers.all;
                  message = "sigil: Machine ID (MID) must be a UUID (passed to --uuid=)";
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
                  ${container.mid} = mkMerge [
                    container.nspawn.config
                    {
                      execConfig = {
                        PrivateUsers = "pick";
                        LinkJournal = "try-host";
                        Parameters = "${container.evaluation.config.system.build.toplevel}/init";
                        Ephemeral = true;
                        Timezone = "off";
                        Boot = false;
                        KillSignal = "SIGRTMIN+3";
                      };
                      filesConfig = {
                        PrivateUsersOwnership = "chown";
                        BindReadOnly = [
                          "/nix/store:/nix/store:idmap"
                        ];
                      };
                      networkConfig = {
                        Private = true;
                        VirtualEthernet = true;
                      };
                    }
                  ];
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
                          Address = "fe80::1/64";
                        }
                      ];
                      routes =
                        optional (container.addresses.gua != null) {
                          Destination = "${container.addresses.gua}/128";
                          Gateway = "fe80::c";
                          GatewayOnLink = true;
                        }
                        ++ optional (container.addresses.ula != null) {
                          Destination = "${container.addresses.ula}/128";
                          Gateway = "fe80::c";
                          GatewayOnLink = true;
                          PreferredSource = cfg.settings.network.ula.source;
                        };
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

              # fold into { <mid> = { networkConfig.VirtualEthernetExtra = [ … all its links … ]; }; }
              byMID = foldl' (acc: e:
                acc
                // {
                  ${e.mid} = {
                    networkConfig.VirtualEthernetExtra =
                      (acc.${e.mid}.networkConfig.VirtualEthernetExtra or []) ++ [e.extra];
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
