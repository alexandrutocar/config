{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.attrsets) attrNames attrValues filterAttrs mapAttrs' nameValuePair;
  inherit (lib.strings) replaceStrings toUpper;
in let
  cfg = config.services.n8n-task-runners;

  n8nCfg = config.services.n8n;
in let
  # Keys of `settings.launcher` become environment variables:
  toEnvName = name:
    if toUpper name == name
    then name
    else "N8N_RUNNERS_" + toUpper (replaceStrings ["-"] ["_"] name);

  launcherEnv = launcherEnvOf cfg.settings.launcher;

  launcherEnvOf = attrs:
    mapAttrs' (name: nameValuePair (toEnvName name))
    (filterAttrs (_: value: value != null) attrs);

  # Read by the launcher only.
  launcherOnlyEnv = [
    "N8N_RUNNERS_AUTH_TOKEN"
    "N8N_RUNNERS_AUTH_TOKEN_FILE"
  ];

  runnerSettingsFormat = pkgs.formats.json {};
in let
  enabledRunners = attrValues (filterAttrs (_: {enable, ...}: enable) cfg.settings.runner);
in {
  options = let
    inherit (lib.lists) subtractLists;
    inherit (lib.options) literalExpression literalMD mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf bool coercedTo int listOf nullOr oneOf package path port str submodule;
  in {
    services.n8n-task-runners = {
      enable = mkEnableOption "n8n task runners for sandboxed Code node execution";

      package = mkOption {
        type = package;
        default = n8nCfg.package;
        defaultText = literalExpression "config.services.n8n.package";
        description = ''
          The n8n package providing the task runner executables.
          It should match the version of the n8n server the runners connect to.
        '';
      };

      launcherPackage = mkPackageOption pkgs "n8n-task-runner-launcher" {};

      stateDir = mkOption {
        type = str;
        default = "/var/lib/n8n-task-runners";
        description = ''
          State directory of the task runners, used as the default working directory of every runner.
          Must be below {file}`/var/lib`, so systemd can manage it via `StateDirectory=`.
        '';
      };

      settings = {
        launcher = mkOption {
          description = ''
            Environment variables for the task runner launcher.
            See <https://docs.n8n.io/hosting/configuration/environment-variables/task-runners/> for available options.

            Kebab-case keys are prefixed with `N8N_RUNNERS_` and upper-cased,
            e.g. `auto-shutdown-timeout` becomes `N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT`.
            All-uppercase keys are passed verbatim, e.g. `GENERIC_TIMEZONE`.

            Any variable can be read from a file by appending `-file` (or `_FILE`) to its name.
            Unless a runner sets its own `allowed-env`, every variable except the auth token
            and the config path is also passed through to the runners.
          '';
          example = literalExpression ''
            {
              auto-shutdown-timeout = 15;
              max-concurrency = 10;
              GENERIC_TIMEZONE = "Europe/Berlin";
            }
          '';
          type = submodule {
            freeformType = attrsOf (oneOf [
              str
              (coercedTo int toString str)
              (coercedTo bool builtins.toJSON str)
            ]);
            options = {
              auth-token-file = mkOption {
                type = nullOr path;
                default = n8nCfg.settings.runners-auth-token-file;
                defaultText = literalExpression "config.services.n8n.settings.runners-auth-token-file";
                description = ''
                  Path to a file containing the shared authentication token
                  used to connect to the n8n task broker.

                  This option is required when any runner is enabled.
                  The file should be readable by the service and not stored in the Nix store.
                '';
              };

              config-path = mkOption {
                type = path;
                default = runnerSettingsFormat.generate "n8n-task-runners.json" {
                  task-runners = map (runner: removeAttrs runner ["enable"]) enabledRunners;
                };
                defaultText = literalMD "generated from {option}`services.n8n-task-runners.settings.runner`";
                description = ''
                  Path to the launcher's {file}`n8n-task-runners.json`.
                  When overridden, {option}`services.n8n-task-runners.settings.runner` no longer affects the launcher,
                  except for which runner types it is started with.
                '';
              };

              task-broker-uri = mkOption {
                type = str;
                default = "http://${n8nCfg.settings.runners-broker-listen-address}:${n8nCfg.settings.runners-broker-port}";
                defaultText = literalExpression ''"http://''${config.services.n8n.settings.runners-broker-listen-address}:''${config.services.n8n.settings.runners-broker-port}"'';
                description = ''
                  URI of the n8n task broker that the runner connects to.
                '';
              };
            };
          };
          default = {};
        };

        runner = mkOption {
          description = ''
            Task runners managed by the launcher. Each entry becomes one element of
            `task-runners` in {file}`n8n-task-runners.json`, with the same keys.
            See <https://github.com/n8n-io/task-runner-launcher/blob/main/docs/setup.md#config-file>.
          '';
          type = attrsOf (
            submodule (
              {name, ...}: {
                freeformType = runnerSettingsFormat.type;

                options = {
                  enable = mkOption {
                    type = bool;
                    default = true;
                    description = ''
                      Whether to enable the ${name} task runner.
                      Only takes effect when {option}`services.n8n-task-runners.enable` is true.
                    '';
                  };

                  runner-type = mkOption {
                    type = str;
                    default = name;
                    defaultText = literalExpression "<name>";
                    description = "Type of task runner. The launcher manages one runner per type.";
                  };

                  workdir = mkOption {
                    type = str;
                    default = cfg.stateDir;
                    defaultText = literalExpression "config.services.n8n-task-runners.stateDir";
                    description = "Directory the runner's command runs in.";
                  };

                  command = mkOption {
                    type = str;
                    description = "Command to start the task runner.";
                  };

                  args = mkOption {
                    type = listOf str;
                    default = [];
                    description = "Arguments and flags to pass to the command.";
                  };

                  health-check-server-port = mkOption {
                    type = coercedTo port toString str;
                    description = "Port for the runner's health check server. Must be unique per runner.";
                  };

                  allowed-env = mkOption {
                    type = listOf str;
                    default =
                      subtractLists launcherOnlyEnv (attrNames (launcherEnvOf (removeAttrs cfg.settings.launcher ["config-path"])));
                    defaultText = literalMD ''
                      The environment variable names produced by {option}`services.n8n-task-runners.settings.launcher`,
                      except the auth token and the config path.
                    '';
                    description = "Environment variables the launcher passes through from its own environment to the runner.";
                  };

                  env-overrides = mkOption {
                    type = attrsOf str;
                    default = {};
                    description = "Environment variables the launcher sets directly on the runner, taking precedence over `allowed-env`.";
                  };
                };
              }
            )
          );
          default = {};
          defaultText = literalExpression ''
            {
              javascript = {
                enable = true;
                command = lib.getExe' config.services.n8n-task-runners.package "n8n-task-runner";
                health-check-server-port = 5681;
              };
              python = {
                enable = true;
                command = lib.getExe' config.services.n8n-task-runners.package "n8n-task-runner-python";
                health-check-server-port = 5682;
              };
            }
          '';
        };
      };
    };
  };

  config = let
    inherit (lib.attrsets) mapAttrs;
    inherit (lib.lists) optional;
    inherit (lib.meta) getExe getExe';
    inherit (lib.modules) mkDefault mkIf mkMerge;
    inherit (lib.strings) concatMapStringsSep hasPrefix removePrefix;
  in let
    anyRunnerEnabled = enabledRunners != [];
  in
    mkIf cfg.enable (
      mkMerge [
        {
          assertions = [
            {
              assertion = hasPrefix "/var/lib/" cfg.stateDir;
              message = "services.n8n-task-runners.stateDir must be below /var/lib.";
            }
            {
              assertion = anyRunnerEnabled -> cfg.settings.launcher.auth-token-file != null;
              message = "services.n8n-task-runners.settings.launcher.auth-token-file must be set when task runners are enabled.";
            }
          ];

          warnings = optional (!anyRunnerEnabled) ''
            services.n8n-task-runners.enable is true, but both JavaScript and Python runners are disabled.
            Enable at least one runner or disable services.n8n-task-runners.
          '';
        }
        {
          services = {
            n8n-task-runners = {
              settings = {
                runner = {
                  javascript = mapAttrs (_: mkDefault) {
                    enable = true;
                    command = getExe' cfg.package "n8n-task-runner";
                    health-check-server-port = 5681;
                  };
                  python = mapAttrs (_: mkDefault) {
                    enable = true;
                    command = getExe' cfg.package "n8n-task-runner-python";
                    health-check-server-port = 5682;
                  };
                };
              };
            };
          };
        }
        {
          systemd = {
            services = {
              n8n-task-runners = mkIf anyRunnerEnabled {
                description = "n8n task runner";
                after = ["network.target"] ++ optional n8nCfg.enable "n8n.service";
                requires = optional n8nCfg.enable "n8n.service";
                wantedBy = ["multi-user.target"];
                environment = launcherEnv;
                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${getExe cfg.launcherPackage} ${concatMapStringsSep " " (runner: runner.runner-type) enabledRunners}";
                  Restart = "on-failure";

                  StateDirectory = removePrefix "/var/lib/" cfg.stateDir;

                  # Hardening
                  DynamicUser = "true";
                  NoNewPrivileges = "yes";
                  PrivateTmp = "yes";
                  PrivateDevices = "yes";
                  DevicePolicy = "closed";
                  ProtectSystem = "strict";
                  ProtectHome = "read-only";
                  ProtectControlGroups = "yes";
                  ProtectKernelModules = "yes";
                  ProtectKernelTunables = "yes";
                  RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
                  RestrictNamespaces = "yes";
                  RestrictRealtime = "yes";
                  RestrictSUIDSGID = "yes";
                  MemoryDenyWriteExecute = "no"; # v8 JIT requires memory segments to be Writable-Executable.
                  LockPersonality = "yes";
                };
              };
            };
          };
        }
      ]
    );

  meta = {
    maintainers = with lib.maintainers; [
      alexandrutocar
    ];
  };
}
