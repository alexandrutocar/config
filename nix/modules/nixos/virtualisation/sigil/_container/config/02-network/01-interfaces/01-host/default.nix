{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra) ip;

  anywhere = ip.network.fromCIDR 6 "::/0";
in {
  systemd = {
    network = {
      networks = {
        "10-host0" = {
          networkConfig = {
            IPv6AcceptRA = false;
            IPv6LinkLocalAddressGenerationMode = "none";
          };

          matchConfig = {
            Name = "host0";
          };

          addresses = [
            {
              # The host0 end, on the container side.
              Address = ip.toCIDR sigil.linkLocal.container;
            }
          ];

          routes = [
            {
              Destination = ip.toCIDR anywhere;
              # The ve-* end, on the host side.
              Gateway = ip.toCompressed sigil.linkLocal.host;
              GatewayOnLink = true;
            }
          ];
        };
      };
    };
  };
}
