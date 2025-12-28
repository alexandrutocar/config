{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.alkaline;
in {
  options.services.alkaline = {
    enable = mkEnableOption "Alkaline";

    package = mkPackageOption pkgs.custom "alkaline" {};

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The host address to bind to";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "The port to listen on";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.alkaline = {
      description = "Alkaline";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      environment = {
        HOST = cfg.host;
        PORT = toString cfg.port;
        NODE_ENV = "production";
      };

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        WorkingDirectory = "${cfg.package}";
        ExecStart = "${pkgs.bun}/bin/bun ${cfg.package}/server/index.mjs";
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        PrivateMounts = true;
      };
    };
  };
}
