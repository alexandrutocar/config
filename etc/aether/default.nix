# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █▀█
# █▀█ ██▄ ░█░ █▀█ ██▄ █▀▄
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.custom.files.list) shallow recursive;
in {
  imports = shallow ./services ++ recursive ./settings;

  # HARDWARE CONFIGURATION
  # ----------------------
  config.facter.reportPath = ./facter.json;
}
