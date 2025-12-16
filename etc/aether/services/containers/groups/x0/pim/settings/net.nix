# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  networking.firewall = {
    allowedTCPPorts = [8080];
  };

  environment.systemPackages = with pkgs; [postgresql];
}
