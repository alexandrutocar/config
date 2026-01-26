# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ █▄░█ █▀ █▀█ █░░ █▀▀
# █▄▄ █▄█ █░▀█ ▄█ █▄█ █▄▄ ██▄
#
# linux console, virtual console...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  # VIRTUAL CONSOLE
  # ---------------
  console = {
    enable = mkDefault true;
    keyMap = mkDefault "de";
  };
}
