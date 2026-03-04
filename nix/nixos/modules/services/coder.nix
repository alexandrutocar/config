{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  cfg = config.services.coder;
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/web-apps/coder.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrs str;
  in {
    services.coder = {
      enable = mkEnableOption "Coder";

      user = mkOption {
        type = str;
        default = "coder";
        description = ''
          User under which the coder service runs.

          ::: {.note}
          If left as the default value this user will automatically be created
          on system activation, otherwise it needs to be configured manually.
          :::
        '';
      };

      group = mkOption {
        type = str;
        default = "coder";
        description = ''
          Group under which the coder service runs.

          ::: {.note}
          If left as the default value this group will automatically be created
          on system activation, otherwise it needs to be configured manually.
          :::
        '';
      };

      package = mkPackageOption pkgs "coder" {};

      dataDir = mkOption {
        type = str;
        description = ''
          Home directory for coder user.
        '';
        default = "/var/lib/coder";
      };

      environment = mkOption {
        type = attrs;
        description = "Extra environment variables to pass run Coder's server with. See Coder documentation.";
        default = {};
        example = {
          CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS = true;
          CODER_OAUTH2_GITHUB_ALLOWED_ORGS = "example.org";
        };
      };
    };
  };

  config = let
    inherit (lib.modules) mkIf;
    inherit (lib.modules) getExe;
  in
    mkIf cfg.enable {
      systemd.services.coder = {
        description = "Coder - Self-hosted developer workspaces on your infra";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        inherit (cfg) environment;

        serviceConfig = {
          ProtectSystem = "full";
          PrivateTmp = "yes";
          PrivateDevices = "yes";
          SecureBits = "keep-caps";
          AmbientCapabilities = "CAP_IPC_LOCK CAP_NET_BIND_SERVICE";
          CacheDirectory = "coder";
          CapabilityBoundingSet = "CAP_SYSLOG CAP_IPC_LOCK CAP_NET_BIND_SERVICE";
          KillSignal = "SIGINT";
          KillMode = "mixed";
          NoNewPrivileges = "yes";
          Restart = "on-failure";
          ExecStart = "${getExe cfg.package} server";
          User = cfg.user;
          Group = cfg.group;
        };
      };

      users.groups = {
        ${cfg.group} = {};
      };
      users.users = {
        ${cfg.user} = {
          inherit (cfg) group;
          home = cfg.dataDir;
          createHome = true;
          isSystemUser = true;
        };
      };
    };
}
