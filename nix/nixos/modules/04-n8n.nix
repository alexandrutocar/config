# Copyright (c) 2003-2025 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ────────────────────────────────────────────────────────────────────────
# NOTE: This module keeps the general structure of the upstream one but
#       applies a few adjustments tailored to my setup. Only the pieces
#       I actually use are kept; unused options have been trimmed. Some
#       defaults have been changed/removed to reduce noise and clutter.
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;
  inherit (lib.strings) replaceStrings toUpper;
in let
  cfg = config.services.n8n;

  runnerCfg = config.services.n8n-task-runners;
in let
  # Keys of `settings` become environment variables:
  toEnvName = name:
    if toUpper name == name
    then name
    else "N8N_" + toUpper (replaceStrings ["-"] ["_"] name);

  n8nEnv =
    mapAttrs' (name: nameValuePair (toEnvName name))
    (filterAttrs (_: value: value != null) cfg.settings);

  customNodesDir = pkgs.linkFarm "n8n-custom-nodes" (
    map (pkg: {
      name = pkg.pname;
      path = "${pkg}/lib/node_modules/${pkg.pname}";
    })
    cfg.customNodes
  );
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/misc/n8n.nix"
  ];

  options = let
    inherit (lib.options) literalExpression mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf bool coercedTo enum int listOf nullOr oneOf package path port str submodule;
  in {
    services.n8n = {
      enable = mkEnableOption "n8n";

      package = mkPackageOption pkgs "n8n" {};

      user = mkOption {
        type = str;
        default = "n8n";
        description = ''
          User ownership of service
        '';
      };

      group = mkOption {
        type = str;
        default = "n8n";
        description = ''
          Group ownership of service
        '';
      };

      stateDir = mkOption {
        type = str;
        default = "/var/lib/n8n";
        description = ''
          State directory of n8n, used as its user folder.
          Must be below {file}`/var/lib`, so systemd can manage it via `StateDirectory=`.
        '';
      };

      customNodes = mkOption {
        type = listOf package;
        default = [];
        example = literalExpression "[ pkgs.n8n-nodes-carbonejs ]";
        description = ''
          List of custom n8n community node packages to load.
          Each package is expected to be an npm package with an `n8n.nodes` entry in its `package.json`.
          The packages are made available to n8n via {option}`services.n8n.settings.custom-extensions`.
        '';
      };

      openFirewall = mkOption {
        type = bool;
        default = false;
        description = "Open ports in the firewall for the n8n web interface.";
      };

      settings = mkOption {
        description = ''
          Environment variables for the n8n service.
          See <https://docs.n8n.io/hosting/configuration/environment-variables/> for available options.

          Kebab-case keys are prefixed with `N8N_` and upper-cased,
          e.g. `encryption-key-file` becomes `N8N_ENCRYPTION_KEY_FILE`.
          All-uppercase keys are passed verbatim, e.g. `WEBHOOK_URL`.

          Any variable can be read from a file by appending `-file` (or `_FILE`) to its name.
        '';
        example = literalExpression ''
          {
            encryption-key-file = "/run/n8n/encryption_key";
            DB_POSTGRESDB_PASSWORD_FILE = "/run/n8n/db_postgresdb_password";
            WEBHOOK_URL = "https://n8n.example.com";
          }
        '';
        type = submodule {
          freeformType = attrsOf (oneOf [
            str
            (coercedTo int toString str)
            (coercedTo bool builtins.toJSON str)
          ]);
          options = {
            GENERIC_TIMEZONE = mkOption {
              type = nullOr str;
              default = config.time.timeZone;
              defaultText = literalExpression "config.time.timeZone";
              description = ''
                The n8n instance timezone. Important for schedule nodes (such as Cron).
              '';
            };

            port = mkOption {
              type = coercedTo port toString str;
              default = 5678;
              description = "The HTTP port n8n runs on.";
            };

            user-folder = mkOption {
              type = path;
              readOnly = true;
              default = cfg.stateDir;
              defaultText = literalExpression "config.services.n8n.stateDir";
              description = ''
                Path where n8n creates the {file}`.n8n` folder.
                This directory stores user-specific data, such as database file and encryption key.
              '';
            };

            diagnostics-enabled = mkOption {
              type = coercedTo bool builtins.toJSON str;
              default = false;
              description = ''
                Whether to share selected, anonymous telemetry with n8n.
                Note that if you set this to false, you can't enable Ask AI in the Code node.
              '';
            };

            version-notifications-enabled = mkOption {
              type = coercedTo bool builtins.toJSON str;
              default = false;
              description = ''
                When enabled, n8n sends notifications of new versions and security updates.
              '';
            };

            custom-extensions = mkOption {
              internal = true;
              type = nullOr path;
              default =
                if cfg.customNodes != []
                then customNodesDir
                else null;
              description = ''
                Path to the directory containing custom nodes.
              '';
            };

            runners-mode = mkOption {
              type = enum [
                "internal"
                "external"
              ];
              default =
                if runnerCfg.enable
                then "external"
                else "internal";
              defaultText = literalExpression ''
                if config.services.n8n-task-runners.enable then "external" else "internal"
              '';
              description = ''
                How to launch and run the task runner.
                `internal` means n8n will launch a task runner as child process.
                `external` means an external orchestrator will launch the task runner,
                such as {option}`services.n8n-task-runners` on this or another host.
              '';
            };

            runners-broker-port = mkOption {
              type = coercedTo port toString str;
              default = 5679;
              description = ''
                Port the task broker listens on for task runner connections.
              '';
            };

            runners-broker-listen-address = mkOption {
              type = str;
              default = "127.0.0.1";
              description = ''
                Address the task broker listens on.
              '';
            };

            runners-auth-token-file = mkOption {
              type = nullOr path;
              default = null;
              description = ''
                Path to a file containing the shared authentication token
                used between the n8n server (task broker) and the task runners.

                This option is required when {option}`services.n8n.settings.runners-mode` is `external`.
                The file should be readable by the service and not stored in the Nix store.
                Use tools like `agenix` or `sops-nix` to manage this secret.
              '';
            };
          };
        };
        default = {};
      };
    };
  };

  config = let
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.strings) hasPrefix removePrefix toInt;
  in
    mkIf cfg.enable (
      mkMerge [
        {
          assertions = [
            {
              assertion = hasPrefix "/var/lib/" cfg.stateDir;
              message = "services.n8n.stateDir must be below /var/lib.";
            }
            {
              assertion = cfg.settings.runners-mode == "external" -> cfg.settings.runners-auth-token-file != null;
              message = "services.n8n.settings.runners-auth-token-file must be set when services.n8n.settings.runners-mode is \"external\".";
            }
          ];
        }
        {
          users = {
            groups = mkIf (cfg.group == "n8n") {
              ${cfg.group} = {};
            };
            users = mkIf (cfg.user == "n8n") {
              ${cfg.user} = {
                isSystemUser = true;
                inherit (cfg) group;
              };
            };
          };
        }
        {
          systemd = {
            services = {
              n8n = {
                description = "n8n service";
                after = ["network.target"];
                wantedBy = ["multi-user.target"];
                environment =
                  n8nEnv
                  // {
                    HOME = cfg.settings.user-folder;
                  };
                serviceConfig = {
                  Type = "simple";
                  ExecStart = getExe cfg.package;
                  Restart = "on-failure";

                  StateDirectory = removePrefix "/var/lib/" cfg.stateDir;
                  StateDirectoryMode = "0750";

                  User = cfg.user;
                  Group = cfg.group;

                  # Hardening
                  NoNewPrivileges = "yes";
                  PrivateTmp = "yes";
                  PrivateDevices = "yes";
                  DevicePolicy = "closed";
                  ProtectSystem = "strict";
                  ProtectHome = "read-only";
                  ProtectControlGroups = "yes";
                  ProtectKernelModules = "yes";
                  ProtectKernelTunables = "yes";
                  RemoveIPC = "yes";
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
        {
          networking = {
            firewall = mkIf cfg.openFirewall {
              allowedTCPPorts = [(toInt cfg.settings.port)];
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
