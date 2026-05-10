# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █░░ █▄▄ █▀▀ █▀▄ █▀█
# █▀█ █▄▄ █▄█ ██▄ █▄▀ █▄█
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./01-settings ++ recursive ./02-services;

  # HARDWARE CONFIGURATION
  # -------- -------------
  hardware.facter.reportPath = ./facter.json;
}
