# ────────────────────────────────────────────────────────────────────────
#
# █▄▄ █▀█ █▀█ ▀█▀ █░░ █▀█ ▄▀█ █▀▄
# █▄█ █▄█ █▄█ ░█░ █▄▄ █▄█ █▀█ █▄▀
#
# bootloader, secure boot...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;
in {
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  # BOOTLOADER
  # ----------
  boot = {
    loader = {
      systemd-boot.enable = mkForce false;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  environment.persistence."/state".directories = [
    config.boot.lanzaboote.pkiBundle
  ];
}
