lib: let
  inherit (lib.extra.ip.network) fromCIDR hostAddress;
in let
  site = {
    ipv6 = {
      # ────────────────────────────────────────────────────────────────────────
      # NOTE: ULA prefix as provided by the router.
      # ────────────────────────────────────────────────────────────────────────
      ula = fromCIDR 6 "fd60:a0ff:34b3:1::/64";
    };

    ipv4 = {
      lan = fromCIDR 4 "192.168.1.0/24";
    };
  };
in {
  network = {
    inherit site;
  };

  router = {
    ipv4 = {
      lan = hostAddress site.ipv4.lan "0.0.0.1";
    };

    ipv6 = {
      ula = hostAddress site.ipv6.ula "::1";
    };
  };

  hosts = {
    fischl = {
      ipv4 = {
        lan = hostAddress site.ipv4.lan "0.0.0.3";
      };

      ipv6 = {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Subnet prefix was reused and Interface ID was generated randomly.
        # ────────────────────────────────────────────────────────────────────────
        # ´                      ┌──► openssl rand -hex 8 | fold -w4 | paste -sd:
        # ────────────────────────────────────────────────────────────────────────
        ula = hostAddress site.ipv6.ula "::3168:6440:959b:1aca";
      };
    };
  };
}
