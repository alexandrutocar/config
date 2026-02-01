# ────────────────────────────────────────────────────────────────────────
#
# █░█ █▀█ ▀█▀ █ █▀▄▀█ █▀▀ ▄▄ █▄▀ █░█ █▀▄▀█ ▄▀█
# █▄█ █▀▀ ░█░ █ █░▀░█ ██▄ ░░ █░█ █▄█ █░▀░█ █▀█
#
# uptime-kuma, uptime...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;

  inherit (container) self;
in {
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_HOST = self.localAddress;
      UPTIME_KUMA_PORT = "8080";
    };
  };

  users.users.uptime-kuma = {
    isSystemUser = true;
    group = "uptime-kuma";
  };

  users.groups.uptime-kuma = {};

  systemd.services.uptime-kuma = {
    serviceConfig = {
      Group = "uptime-kuma";
      User = "uptime-kuma";
      DynamicUser = mkForce false;
    };
  };
}
