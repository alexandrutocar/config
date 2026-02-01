# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ ▀█▀
# █░▀█ ██▄ ░█░
#
# network, firewall, dns, certificates...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  self,
  ...
}: {
  networking.useNetworkd = true;

  networking.firewall = {
    allowedTCPPorts = [8080];
  };

  systemd.network = let
    inherit (container) self intranet-dns;
  in {
    enable = true;
    networks = {
      "25-dns" = {
        matchConfig = {
          Kind = "veth";
          Name = "eth0";
        };
        linkConfig = {
          RequiredForOnline = false;
        };
        networkConfig = {
          Address = self.localAddress;
          Gateway = self.hostAddress;

          DNS = [
            intranet-dns.localAddress
          ];

          DNSDefaultRoute = true;

          Domains = ["~aether.ip" "~."];
        };
        routes = [
          {
            Gateway = self.hostAddress;
          }
          {
            Destination = self.hostAddress;
            Scope = "link";
          }
        ];
      };
    };
  };

  # CERTIFICATE
  # -----------
  security.pki.certificates = [
    (builtins.readFile (self + /.pki/ca/root/x0.pem))
  ];
}
