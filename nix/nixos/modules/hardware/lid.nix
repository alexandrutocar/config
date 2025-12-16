# ────────────────────────────────────────────────────────────────────────
# NOTE: Beware, this option does not yet interact with the real sensor,
#       but forces software components to ignore lid sensor indication.
# ────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  ...
}: let
  # Utilities
  inherit (lib.options) mkEnableOption;
  inherit (lib) mkIf;

  # Configuration
  cfg = config.hardware.sensor.lid;
  # Everything Else
in {
  options.hardware.sensor.lid = {
    enable =
      mkEnableOption "lid"
      // {
        default = true;
      };
  };

  config = mkIf (!cfg.enable) {
    # Disable sleep, suspend, hibernate, and hybrid-sleep targets.
    # https://www.reddit.com/r/NixOS/comments/17motun/comment/k7n21u5
    systemd = {
      targets = {
        sleep = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
        suspend = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
        hibernate = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
        hybrid-sleep = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
      };
    };

    # Ignore lid switch if the machine is plugged in.
    services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  };
}
