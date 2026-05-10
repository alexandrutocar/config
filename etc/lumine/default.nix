# ────────────────────────────────────────────────────────────────────────
#
# █░░ █░█ █▀▄▀█ █ █▄░█ █▀▀
# █▄▄ █▄█ █░▀░█ █ █░▀█ ██▄
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive shallow;
in {
  imports = recursive ./01-settings ++ shallow ./02-services;

  # HARDWARE CONFIGURATION
  # -------- -------------
  hardware.facter.reportPath = ./facter.json;
}
