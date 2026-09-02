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
  imports = singleton (self + "/etc/shared/01-settings/net.nix");

  # CERTIFICATE
  # -----------
  security.pki.certificateFiles = [
    "${pkgs.certs}/etc/ssl/anchor/intra.net.pem"
  ];
}
