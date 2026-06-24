# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall, dns...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  # NETWORKD
  # --------
  systemd.network.enable = mkDefault true;
  networking.useNetworkd = mkDefault true;

  # RESOLVER
  # --------
  services.resolved.enable = mkDefault true;

  # FIREWALL
  # --------
  networking.nftables.enable = mkDefault true;
}
