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

  # Network Interface [+]
  systemd.network = {
    networks."25-wlan0" = {
      # [Match]
      matchConfig = {
        Type = "wlan";
        SSID = "heim";
      };

      # [Network]
      networkConfig = {
        DNSDefaultRoute = true;
        DHCP = "ipv4";
        DNS = [
          "192.168.0.10"
          # ────────────────────────────────────────────────────────────────────────
          # TODO: Enable IPv6 when IPv6 for containers is restored.
          # ────────────────────────────────────────────────────────────────────────
          # "fe80::9ecc:83ff:fec8:1010"
        ];
        DNSOverTLS = "yes";
        Domains = ["~aether.ip" "~."];
      };

      dhcpV4Config = {
        UseDNS = false;
      };
      dhcpV6Config = {
        UseDNS = false;
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
