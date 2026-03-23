# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █▀█
# █▀█ ██▄ ░█░ █▀█ ██▄ █▀▄
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) shallow recursive;
in {
  imports = shallow ./services ++ recursive ./settings;

  # HARDWARE CONFIGURATION
  # ----------------------
  hardware.facter.reportPath = ./facter.json;
}
