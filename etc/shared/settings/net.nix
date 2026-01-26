# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall, wireless, dns...
#
# ────────────────────────────────────────────────────────────────────────
{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  # NETWORKD
  # --------
  systemd.network.enable = mkDefault true;
  networking.useNetworkd = mkDefault true;

  # RESOLVER
  # --------
  services.resolved = {
    enable = mkDefault true;
  };

  networking = {
    # FIREWALL
    # --------
    nftables.enable = mkDefault true;

    # WIRELESS
    # --------
    wireless.iwd = {
      enable = mkDefault true;
      settings = {
        General = {
          AddressRandomization = mkDefault "network";
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
