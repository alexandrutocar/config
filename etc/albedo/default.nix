# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █░░ █▄▄ █▀▀ █▀▄ █▀█
# █▀█ █▄▄ █▄█ ██▄ █▄▀ █▄█
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.custom.files.list) recursive;
in {
  imports = recursive ./services ++ recursive ./settings;

  # HARDWARE CONFIGURATION
  # ----------------------
  config.facter.reportPath = ./facter.json;
}
