{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.openbao-agent;
in let
  filesRoot = "/tmp/vault/";
  envFilesRoot = "/run/keys/environment/";
in {
  options = let
    inherit (lib.options) mkEnableOption mkOption;
    inherit (lib.types) attrsOf bool enum lines listOf nullOr path str submodule unspecified;
  in {
    services.openbao-agent = mkOption {
      type = attrsOf (submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "OpenBao Agent";

          env = {
            changeAction = mkOption {
              description = "What to do if any secrets in the environment change.";
              type = enum [
                "none"
                "restart"
                "stop"
              ];
              default = "restart";
            };

            templateFiles = mkOption {
              type = attrsOf (submodule ({...}: {
                options = {
                  file = mkOption {
                    description = "A consul-template file which produces EnvironmentFile-compatible output.";
                    type = path;
                  };

                  perms = mkOption {
                    readOnly = true;
                    internal = true;
                    description = "The octal mode of the environment file as a string.";
                    type = str;
                    default = "0400";
                  };
                };
              }));
              default = {};
            };

            template = mkOption {
              description = "A consul-template snippet which produces EnvironmentFile-compatible output.";
              type = nullOr lines;
              default = null;
            };

            perms = mkOption {
              readOnly = true;
              internal = true;
              description = "The octal mode of the environment file as a string.";
              type = str;
              default = "0400";
            };
          };

          files = mkOption {
            type = attrsOf (submodule ({name, ...}: {
              options = {
                changeAction = mkOption {
                  description = ''
                    What to do if any secrets in this file changes.
                    If left unspecified, the defaultChangeAction for this service takes effect.
                  '';
                  type = nullOr (enum [
                    "none"
                    "reload"
                    "restart"
                    "stop"
                  ]);
                  default = null;
                };

                templateFile = mkOption {
                  description = "A consul-template file. Conflicts with template.";
                  type = nullOr path;
                  default = null;
                };

                template = mkOption {
                  description = "A consul-template snippet. Conflicts with templateFile.";
                  type = nullOr lines;
                  default = null;
                };

                perms = mkOption {
                  description = "The octal mode of the secret file as a string.";
                  type = str;
                  default = "0400";
                };

                path = mkOption {
                  readOnly = true;
                  description = "The path to the secret file inside the unit's namespace's PrivateTmp.";
                  type = str;
                  default = "${filesRoot}${name}";
                };
              };
            }));
            default = {};
          };

          settings = mkOption {
            description = "OpenBao Agent configuration.";
            type = submodule {
              freeformType = attrsOf unspecified;

              options = {
                auto_auth = mkOption {
                  type = submodule {
                    freeformType = attrsOf unspecified;

                    options = {
                      method = mkOption {
                        type = listOf (submodule {
                          freeformType = attrsOf unspecified;

                          options = {
                            type = mkOption {
                              type = str;
                            };

                            config = mkOption {
                              type = attrsOf unspecified;
                            };
                          };
                        });
                        default = [];
                      };
                    };
                  };
                  default = {};
                };

                template_config = mkOption {
                  type = submodule {
                    freeformType = attrsOf unspecified;

                    options = {
                      exit_on_retry_failure = mkOption {
                        type = bool;
                        default = true;
                      };
                    };
                  };
                  default = {};
                };
              };
            };
          };

          serviceName = {
            primary = mkOption {
              type = str;
              default = name;
              defaultText = lib.literalExpression ''
                "''${name}.service"
              '';
              description = ''
                Systemd service name that actually gets the
                secrets in its temporary directory.
              '';
            };

            sidecar = mkOption {
              type = str;
              default = "openbao-agent-${name}";
              defaultText = lib.literalExpression ''
                "openbao-agent-''${name}"
              '';
              description = ''
                Systemd service name that actually gets the
                secrets in its temporary directory.
              '';
            };
          };
        };
      }));
      default = {};
    };
  };

  config = let
    inherit (lib.extra.options) mkScopedMerge;
    inherit (lib.modules) mkDefault mkMerge;
    inherit (lib.meta) getExe;
  in
    mkMerge [
      (mkScopedMerge [["assertions"]]
        (lib.mapAttrsToList
          (sidecarName: sidecarConfig: {
            assertions = lib.flatten (lib.mapAttrsToList
              (fileName: fileConfig: [
                {
                  assertion = !(fileConfig.templateFile == null && fileConfig.template == null);
                  message = "services.openbao-sidecar.${sidecarName}.files.${fileName}: One of the 'templateFile' and 'template' options must be specified.";
                }
                {
                  assertion = !(fileConfig.templateFile != null && fileConfig.template != null);
                  message = "services.openbao-sidecar.${sidecarName}.files.${fileName}: Both 'templateFile' and 'template' options are specified, but they are mutually exclusive.";
                }
              ])
              sidecarConfig.files);
          })
          cfg))
      (mkScopedMerge [["assertions"]]
        (lib.mapAttrsToList
          (sidecarName: sidecarConfig: {
            assertions = [
              {
                assertion = let
                  primaryServiceConfig = config.systemd.services.${sidecarConfig.serviceName.primary}.serviceConfig;
                in
                  !(primaryServiceConfig ? PrivateTmp && !primaryServiceConfig.PrivateTmp);
                message = ''
                  services.openbao-sidecar.${sidecarName}:
                      The specified service has PrivateTmp= (systemd.exec(5)) disabled, but it must
                      be enabled to share secrets between the sidecar service and the infected service.
                '';
              }
            ];
          })
          cfg))
      (mkScopedMerge [["systemd" "services"]]
        (lib.mapAttrsToList
          (agentName: agentConfig: let
            renderAgentConfig = targetService: targetServiceConfig: cfg: let
              mkCommand = requestedAction: let
                restartAction =
                  {
                    restart = "try-restart";
                    reload = "try-reload-or-restart";
                    stop = "stop";
                  }."${requestedAction}";
              in
                if requestedAction == "none"
                then null
                else "systemctl ${restartAction} ${lib.escapeShellArg "${targetService}.service"}";

              environmentFileTemplates = let
                changeCommand = mkCommand cfg.env.changeAction;
              in
                (lib.optional (cfg.env.template != null)
                  ({
                      destination = "${envFilesRoot}${targetService}/EnvFile";
                      contents = cfg.env.template;
                      inherit (cfg.env) perms;
                    }
                    // lib.optionalAttrs (changeCommand != null) {
                      command = changeCommand;
                    }))
                ++ (lib.mapAttrsToList
                  (name: {
                    file,
                    perms,
                  }: ({
                      destination = "${envFilesRoot}${targetService}/${name}.EnvFile";
                      source = file;
                      inherit perms;
                    }
                    // lib.optionalAttrs (changeCommand != null) {
                      command = changeCommand;
                    }))
                  cfg.env.templateFiles);

              secretFileTemplates =
                lib.mapAttrsToList
                (
                  _name: {
                    changeAction,
                    templateFile,
                    template,
                    perms,
                    path,
                  }:
                    rec {
                      command = let
                        user = targetServiceConfig.serviceConfig.User or null;
                        group = targetServiceConfig.serviceConfig.Group or null;
                        escapedUser = lib.escapeShellArg user;
                        escapedGroup = lib.escapeShellArg group;
                        changeCommand = mkCommand (
                          if changeAction != null
                          then changeAction
                          else "restart"
                        );
                      in
                        builtins.concatStringsSep ";"
                        ([
                            "chown ${lib.optionalString (user != null) escapedUser}:${lib.optionalString (group != null) escapedGroup} ${lib.escapeShellArg destination}"
                          ]
                          ++ lib.optionals (changeCommand != null) [
                            changeCommand
                          ]);
                      destination = path;
                      inherit perms;
                    }
                    // lib.optionalAttrs (template != null) {contents = template;}
                    // lib.optionalAttrs (templateFile != null) {source = templateFile;}
                )
                cfg.files;
            in {
              inherit
                environmentFileTemplates
                secretFileTemplates
                ;

              environmentFiles =
                map
                (tpl: tpl.destination)
                environmentFileTemplates;

              secretFiles =
                map
                (tpl: tpl.destination)
                secretFileTemplates;

              agentConfig =
                cfg.agentConfig
                // {
                  template =
                    environmentFileTemplates
                    ++ secretFileTemplates;
                };
            };
          in let
            rendered = renderAgentConfig agentName config.systemd.services.${agentConfig.serviceName.primary} agentConfig;
            agentCfgFile =
              pkgs.writeText "${agentConfig.serviceName.sidecar}.json"
              (builtins.toJSON agentConfig.settings);
          in {
            systemd.services = {
              ${agentConfig.serviceName.primary} = {
                after = [
                  "${agentConfig.serviceName.sidecar}.service"
                ];
                bindsTo = [
                  "${agentConfig.serviceName.sidecar}.service"
                ];
                unitConfig = {
                  JoinsNamespaceOf = "${agentConfig.serviceName.sidecar}.service";
                };
                serviceConfig = {
                  EnvironmentFile = rendered.environmentFiles;
                  PrivateTmp = mkDefault true;
                };
              };
              ${agentConfig.serviceName.sidecar} = {
                requires = ["network.target"];

                after = ["network.target"];

                path = [pkgs.getent];

                wants = ["${agentConfig.serviceName.primary}.service"];

                before = ["${agentConfig.serviceName.primary}.service"];

                unitConfig = {
                  StartLimitIntervalSec = mkDefault 30;
                  StartLimitBurst = mkDefault 6;
                  StopPropagatedFrom = [
                    "${agentConfig.serviceName.primary}.service"
                  ];
                };

                serviceConfig = {
                  Type = "notify";

                  ExecStart = let
                    filesToMonitor =
                      pkgs.writeText "files-to-monitor"
                      (builtins.concatStringsSep "\n"
                        (map (path: path.destination) rendered.environmentFileTemplates
                          ++ map (path: path.destination) rendered.secretFileTemplates));
                  in "${getExe pkgs.openbao} -config=${agentCfgFile}";

                  ExecStartPre = let
                    precreateDirectories = serviceName: {
                      user ? null,
                      group ? null,
                    }: let
                      userEscaped = lib.escapeShellArg (toString user);
                      groupEscaped = lib.escapeShellArg (toString group);
                    in
                      pkgs.writeShellScript "precreate-dirs-for-${serviceName}" ''
                        set -eux
                        (
                          umask 027
                          mkdir -p ${envFilesRoot}

                          mkdir -p ${filesRoot}
                          chown ${lib.optionalString (user != null) userEscaped}:${lib.optionalString (group != null) groupEscaped} ${filesRoot}
                        )
                      '';

                    systemdServiceConfig = config.systemd.services."${agentConfig.serviceName.primary}".serviceConfig;
                  in
                    precreateDirectories agentName
                    (lib.optionalAttrs (systemdServiceConfig ? User) {user = systemdServiceConfig.User;}
                      // lib.optionalAttrs (systemdServiceConfig ? Group) {group = systemdServiceConfig.Group;});

                  PrivateTmp = mkDefault true;

                  Restart = mkDefault "on-failure";
                  RestartSec = mkDefault 5;
                };
              };
            };
          })
          cfg))
    ];
}
