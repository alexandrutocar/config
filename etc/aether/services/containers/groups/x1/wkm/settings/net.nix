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
    inherit (container) self x0-dns;
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
          Address = self.address;
          Gateway = self.gateway;

          DNS = [
            x0-dns.address
          ];

          DNSDefaultRoute = true;

          Domains = ["~aether.ip" "~."];
        };
        routes = [
          {
            Gateway = self.gateway;
          }
          {
            Destination = self.gateway;
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
