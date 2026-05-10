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
  imports = singleton (self + /etc/shared/01-settings/net.nix);

  # ────────────────────────────────────────────────────────────────────────
  # NOTE(SECURITY): Having wireless driver blacklisted reduces the
  #                 attack surface.
  # ────────────────────────────────────────────────────────────────────────
  boot.blacklistedKernelModules = ["iwlwifi"];
  networking.wireless.iwd.enable = false;

  # SYSTEMD NETWORK
  # ------- -------
  systemd.network = {
    networks = {
      # Network Interface [+]
      "25-enp0s20" = {
        # [Match]
        matchConfig = {
          MACAddress = "00:11:22:68:05:7c";
        };

        # [Link]
        linkConfig = {
          RequiredForOnline = "routable";
        };

        # [Network]
        networkConfig = {
          Address =
            [
              "192.168.1.2/24"
            ]
            ++ [
              "fd4b:ad02:1b77:1:0020:61fc:3462:bf01/64" # ULA
              "2a00:5ba0:8009:5f40:1:b03f:2f2a:c1df/64" # WAN
            ];
          Gateway =
            ["192.168.1.1"]
            ++ [
              "fd4b:ad02:1b77:1:e228:6dff:fe1d:8a9c" # ULA
            ];

          DNSDefaultRoute = true;
          DNSOverTLS = "yes";

          DNS = [
            "10.0.0.6" # intranet-dns container
            # ────────────────────────────────────────────────────────────────────────
            # TODO: Enable IPv6.
            # ────────────────────────────────────────────────────────────────────────
            # "fd31::100:1"
          ];

          Domains = ["~aether.ip" "~."];
        };

        # [DHCP]
        dhcpConfig = {
          Hostname = "Aether";
          SendHostname = true;
        };
      };
    };
  };

  # CERTIFICATE
  # -----------
  security.pki.certificates = [
    (builtins.readFile (self + /.pki/ca/root/x0.pem))
  ];
}
