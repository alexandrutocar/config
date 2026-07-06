# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █▀█
# █▀█ ██▄ ░█░ █▀█ ██▄ █▀▄
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./_config;

  # HARDWARE CONFIGURATION
  # -------- -------------
  hardware.facter.reportPath = ./report.json;
}
