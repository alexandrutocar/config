# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀ █▀▄
# █░▀█ ▄█ █▄▀
#
# nsd, dns, ueuie.dev...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  lib,
  ...
}: let
  inherit (container) self;
in {
  services.prosody = {
    enable = false;

    settings = {
      allow_registration = false;
    };

    configFile = ../etcetera/prosody.cfg.lua;
  };

  networking.firewall = {
    allowedTCPPorts = [5222];
    allowedUDPPorts = [];
  };
}
