# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▄ █▀▄▀█ █ █▄░█ █ █▀ ▀█▀ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
# █▀█ █▄▀ █░▀░█ █ █░▀█ █ ▄█ ░█░ █▀▄ █▀█ ░█░ █ █▄█ █░▀█
#
# user management policy...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  # IMMUTABLE USERS
  # ---------------
  users.mutableUsers = mkDefault false;

  # USER MANAGEMENT UTILITIES
  # -------------------------
  services.userborn.enable = mkDefault true;
}
