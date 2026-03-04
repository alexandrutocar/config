# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall, wireless, wired...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkMerge;
in {
  imports = singleton (self + /etc/shared/settings/net.nix);

  # WIRELESS
  # --------
  networking.wireless.iwd = {
    settings = {
      General = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO: Harden `iwd` by letting the daemon encrypt network configuraions.
        # - Enable hybrid encryption.
        # - Generate `iwd` secret passphrase/password and back it up.
        # - Create `iwd` credential (/etc/credstore/iwd.secret).
        # ────────────────────────────────────────────────────────────────────────
        # SystemdEncrypt = "iwd";
      };
    };
  };

  # UTILITIES
  # ---------
  environment.systemPackages = with pkgs; [
    iwqr
  ];

  # CERTIFICATE
  # -----------
  security.pki.certificates = [
    (builtins.readFile (self + /.pki/ca/root/x0.pem))
  ];

  # PERSISTENCE
  # -----------
  environment.persistence."/state".directories = [
    # iwd takes full control of network configuration and
    # does not allow it to be read-only (or symlinked).
    "/var/lib/iwd"
  ];
}
