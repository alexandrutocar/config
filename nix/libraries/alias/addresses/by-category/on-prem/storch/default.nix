lib: let
  inherit (lib.extra) ip;
in let
  site = {
    ipv6 = {
      # ────────────────────────────────────────────────────────────────────────
      # NOTE: ULA prefix as provided by the router.
      # ────────────────────────────────────────────────────────────────────────
      ula = ip.network.fromCIDR 6 "fd60:a0ff:34b3:1::/64";
    };

    ipv4 = {
      lan = ip.network.fromCIDR 4 "192.168.1.0/24";

      wan = let
        AS3320 = {
          DE-TELEKOM-20010806 = ip.network.fromCIDR 4 "80.128.0.0/11";
        };
      in
        ip.network.hostAddress AS3320.DE-TELEKOM-20010806 (builtins.fromJSON (builtins.readFile ./_volatile/router.ipv4.wan.json));
    };
  };
in {
  network = {
    inherit site;
  };

  router = {
    ipv4 = {
      lan = ip.network.hostAddress site.ipv4.lan "0.0.0.1";
    };

    ipv6 = {
      ula = ip.network.hostAddress site.ipv6.ula "::1";
    };
  };

  hosts = {
    fischl = {
      ipv4 = {
        lan = ip.network.hostAddress site.ipv4.lan "0.0.0.3";
      };

      ipv6 = {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Subnet prefix was reused and Interface ID was generated randomly.
        # ────────────────────────────────────────────────────────────────────────
        # ´                      ┌──► openssl rand -hex 8 | fold -w4 | paste -sd:
        # ────────────────────────────────────────────────────────────────────────
        ula = ip.network.hostAddress site.ipv6.ula "::3168:6440:959b:1aca";
      };
    };
  };
}
