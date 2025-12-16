# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall, wireless, dns...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  # NETWORKD
  # --------
  systemd.network.enable = true;
  networking.useNetworkd = true;

  # RESOLVER
  # --------
  services.resolved = {
    enable = true;
  };

  networking = {
    # FIREWALL
    # --------
    nftables.enable = true;

    # WIRELESS
    # --------
    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          AddressRandomization = "network";
        };
      };
    };
  };

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
  ];
}
