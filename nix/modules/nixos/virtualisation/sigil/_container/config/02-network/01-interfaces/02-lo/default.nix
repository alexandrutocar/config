{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.ip) ranges toCIDR;
  inherit (lib.lists) filter;
in {
  systemd = {
    network = {
      networks = {
        "10-lo" = {
          matchConfig = {
            Name = "lo";
          };
          # ::1/128 plus the container's own addresses, which are /128 by type.
          address = map toCIDR (
            ranges.ipv6.loopback
            ++ filter (a: a != null) [
              sigil.self.addresses.gua
              sigil.self.addresses.ula
            ]
          );
        };
      };
    };
  };
}
