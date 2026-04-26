# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █▀▀ █▀ █▄▀ ▀█▀ █▀█ █▀█
# █▄▀ ██▄ ▄█ █░█ ░█░ █▄█ █▀▀
#
# █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# ██▄ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
#
# compositor, display, keybindings, notifications,
# wallpaper, scripts...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive (self + /dot/shared/settings/appearance);
}
