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
  imports = singleton (self + /etc/shared/01-settings/net.nix);

  # WIRELESS
  # --------
  networking.wireless.iwd = {
    enable = true;

    settings = {
      General = {
        AddressRandomization = "network";
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

  # SYSTEMD NETWORK
  # ------- -------
  systemd.network = {
    networks = {
      # Network Interface [+]
      "25-wlan0" = {
        # [Match]
        matchConfig = {
          Type = "wlan";
          SSID = "Specht";
        };

        # [Link]
        linkConfig = {
          RequiredForOnline = "routable";
        };

        # [Network]
        networkConfig = {
          Address =
            ["192.168.1.3/24"]
            ++ [
              "fd4b:ad02:1b77:1:e567:df0a:5754:97ed/64" # ULA
            ];

          Gateway =
            ["192.168.1.1"]
            ++ [
              "fd4b:ad02:1b77:1:e228:6dff:fe1d:8a9c" # ULA
            ];
        };

        # [DHCP]
        dhcpConfig = {
          Hostname = "Albedo";
          SendHostname = true;
        };
      };
    };
  };

  # UTILITIES
  # ---------
  environment.systemPackages = with pkgs; [
    (impala.overrideAttrs (oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [copyDesktopItems];

      desktopItems = [
        (makeDesktopItem {
          name = "impala";
          exec = "impala %u";
          terminal = true;
          comment = oldAttrs.meta.description;
          desktopName = "Impala";
          genericName = "Terminal-based wireless dashboard.";
          categories = [
            "System"
            "Utility"
            "Settings"
          ];
          keywords = [
            "iwd"
            "wireless"
            "network"
            "impala"
            "nm"
          ];
        })
      ];
    }))
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
