# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █░░ █▄▄ █▀▀ █▀▄ █▀█
# █▀█ █▄▄ █▄█ ██▄ █▄▀ █▄█
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./services ++ recursive ./settings;

  # HARDWARE CONFIGURATION
  # ----------------------
  hardware.facter.reportPath = ./facter.json;
}
