# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, dns...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkForce;
in {
  # NETWORKD
  # --------
  # ────────────────────────────────────────────────────────────────────────
  # TODO: Move to .nspawn files without added abstraction layer.
  # PLAN:
  #       1.  Evaluate feature parity between containers and
  #           https://github.com/fpletz/nixos-nspawn.
  #       2.  Integrate customized version of nixos-nspawn module.
  #       3.  Disable "containers".
  # ────────────────────────────────────────────────────────────────────────
  # networking.useNetworkd = true;
  networking.enableIPv6 = false;

  networking = {
    # FIREWALL
    # --------
    nftables.enable = true;

    # RESOLVER
    # --------
    # Use systemd-resolved inside the container.
    # https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = mkForce false;
  };

  services.resolved = {
    enable = true;
  };
}
