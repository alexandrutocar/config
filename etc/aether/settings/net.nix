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
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/settings/net.nix);

  networking = {
    # WIRELESS
    # --------
    wireless.iwd = {
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

    useNetworkd = true;
    enableIPv6 = false;
  };

  # SYSTEMD NETWORK
  # ------- -------
  systemd.network = {
    networks = {
      # Network Interface [+]

      "25-wlp2s0" = {
        # [Match]
        matchConfig = {
          Type = "wlan";
          SSID = "heim";
        };

        # [Link]
        linkConfig = {
          RequiredForOnline = "routable";
        };

        # [Network]
        networkConfig = {
          Address = ["192.168.0.10/24" "fe80::9ecc:83ff:fec8:1010/64"];
          Gateway = ["192.168.0.1" "fe80::9ecc:83ff:fec8:46aa"];
        };
      };
    };
  };

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
