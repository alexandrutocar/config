# ────────────────────────────────────────────────────────────────────────
# WIP: This is a service for Fava, a friendly Beancount web-interface.
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.fava;
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  options = {
    services.fava = let
      inherit (lib.options) mkEnableOption mkOption mkPackageOption;
      inherit (lib.types) path port str;
    in {
      enable = mkEnableOption "fava";

      package = mkPackageOption pkgs "fava" {};

      settings = {
        port = mkOption {
          type = port;
          default = 5000;
          description = "Port on which Fava will listen";
        };

        host = mkOption {
          type = str;
          default = "127.0.0.1";
          description = "Host address to bind to";
        };

        bean = mkOption {
          type = str;
          default = "transactions.bean";
          description = "Main beancount file to load (relative to dataDir)";
        };
      };

      user = mkOption {
        type = str;
        default = "fava";
        description = ''
          User account under which Fava runs.
        '';
      };

      group = mkOption {
        type = str;
        default = "fava";
        description = ''
          Group account under which Fava runs.
        '';
      };

      dataDir = mkOption {
        type = path;
        default = "/var/lib/fava";
        description = "Directory containing beancount files";
      };
    };
  };

  config = let
    inherit (lib.lists) singleton;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf;
  in
    mkIf cfg.enable {
      users.users.${cfg.user} = mkIf (cfg.user == "fava") {
        description = "Fava service user";
        isSystemUser = true;
        inherit (cfg) group;
      };

      users.groups.${cfg.group} = mkIf (cfg.group == "fava") {};

      systemd.services.fava = {
        description = "Fava";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "simple";
          User = "${cfg.user}";
          Group = "${cfg.group}";

          ExecStart = ''
            ${getExe cfg.package} --host ${cfg.settings.host} --port ${toString cfg.settings.port} ${cfg.dataDir}/${cfg.settings.bean}
          '';

          Restart = "on-failure";
          RestartSec = "5s";

          # Hardening options
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];

          # File system access
          ReadWritePaths = singleton cfg.dataDir;

          # Capabilities
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";

          # Security
          PrivateUsers = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          UMask = "0027";
        };
      };

      systemd.tmpfiles.settings."10-fava" = {
        "${cfg.dataDir}" = {
          d = {
            inherit (cfg) user group;
            mode = "0750";
          };
        };
      };
    };
}
