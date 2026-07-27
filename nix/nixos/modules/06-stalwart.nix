{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.stalwart;
  configFile = configFormat.generate "config.json" cfg.settings;
  configFormat = pkgs.formats.json {};
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/mail/stalwart.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) path str;
  in {
    services.stalwart = {
      enable = mkEnableOption "stalwart";

      package = mkPackageOption pkgs "stalwart_0_16" {};

      settings = mkOption {
        inherit (configFormat) type;
        default = {};
        description = ''
          Configuration options for the Stalwart server.
          See <https://stalw.art/docs/configuration> for available options.

          By default, the module is configured to store everything locally.
        '';
      };

      dataDir = mkOption {
        type = path;
        default = "/var/lib/stalwart";
        description = ''
          Data directory for stalwart
        '';
      };

      user = lib.mkOption {
        type = str;
        default = "stalwart";
        description = ''
          User ownership of service
        '';
      };

      group = lib.mkOption {
        type = str;
        default = "stalwart";
        description = ''
          Group ownership of service
        '';
      };
    };
  };

  config = let
    inherit (lib.modules) mkIf;
  in
    mkIf cfg.enable {
      users = {
        groups = mkIf (cfg.group == "stalwart") {
          ${cfg.group} = {};
        };
        users = mkIf (cfg.user == "stalwart") {
          ${cfg.user} = {
            isSystemUser = true;
            inherit (cfg) group;
          };
        };
      };

      systemd.tmpfiles.settings = {
        "10-stalwart" = {
          ${cfg.dataDir}.d = {
            inherit (cfg) group user;
          };
        };
      };

      systemd = {
        services.stalwart = {
          description = "Stalwart Server";
          wantedBy = ["multi-user.target"];
          after = [
            "local-fs.target"
            "network.target"
          ];

          serviceConfig = {
            Type = "simple";
            LimitNOFILE = 65536;
            KillMode = "process";
            KillSignal = "SIGINT";
            Restart = "on-failure";
            RestartSec = 5;
            SyslogIdentifier = "stalwart";

            ExecStart = [
              "${lib.getExe cfg.package} --config=${configFile}"
            ];
            Environment = [
              "STALWART_RECOVERY_MODE=1"
              "STALWART_RECOVERY_MODE_PORT=8080"
              "STALWART_RECOVERY_MODE_LOG_LEVEL=info"
              "STALWART_RECOVERY_ADMIN=admin:admin"
            ];

            ReadWritePaths = [
              cfg.dataDir
            ];
            CacheDirectory = "stalwart";
            StateDirectory = "stalwart";

            # Upstream uses "stalwart" as the username since 0.12.0
            User = cfg.user;
            Group = cfg.group;

            # Bind standard privileged ports
            AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
            CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];

            # Hardening
            DeviceAllow = [""];
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            PrivateDevices = true;
            PrivateUsers = false; # incompatible with CAP_NET_BIND_SERVICE
            ProcSubset = "pid";
            PrivateTmp = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
            ];
            UMask = "0077";
          };
          unitConfig.ConditionPathExists = [
            "${configFile}"
          ];
        };
      };

      # Make admin commands available in the shell
      environment.systemPackages = [cfg.package];
    };

  meta = {
    maintainers = with lib.maintainers; [
      alexandrutocar
    ];
  };
}
