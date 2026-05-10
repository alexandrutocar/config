# ────────────────────────────────────────────────────────────────────────
#
# █▀ █░█ █▀▀ █░░ █░░
# ▄█ █▀█ ██▄ █▄▄ █▄▄
#
# shell, privacy guard, terminal, utilities ...
#
# ────────────────────────────────────────────────────────────────────────
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/01-settings/shell.nix);

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
    enableSSHSupport = true;

    settings = {
      ttyname = "$GPG_TTY";
      default-cache-ttl = 60;
      max-cache-ttl = 120;
    };
  };

  # UTILITIES
  # ---------
  environment.systemPackages = with pkgs; [
    # Tools for backing up keys
    paperkey
    pgpdump
    parted

    age

    # Yubico's official tools
    yubikey-manager
    yubico-piv-tool

    # Testing
    ent

    # Password generation tools
    diceware
    pwgen
    rng-tools

    # Might be useful beyond the scope of the guide
    cfssl
    pcsc-tools
  ];

  services.udev = {
    packages = with pkgs; [
      yubikey-manager
    ];
  };
}
