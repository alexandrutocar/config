lib: let
  inherit (lib.extra) ip;
in let
  site = {
    ipv6 = {
      gua = let
        AS680 = {
          DE-UNIVERSITAET-BONN-20130319 = ip.network.fromCIDR 6 "2a00:5ba0::/29";
        };
      in
        ip.network.subnetFromBits AS680.DE-UNIVERSITAET-BONN-20130319 60 "0:0:8009:5f40::";

      # ────────────────────────────────────────────────────────────────────────
      # NOTE: ULA prefix as provided by the router.
      # ────────────────────────────────────────────────────────────────────────
      ula = ip.network.fromCIDR 6 "fd4b:ad02:1b77:1::/64";
    };

    ipv4 = {
      lan = ip.network.fromCIDR 4 "192.168.1.0/24";

      wan = let
        AS680 = {
          DE-DFN-20000808 = ip.network.fromCIDR 4 "212.201.0.0/16";
        };
      in
        ip.network.hostAddress AS680.DE-DFN-20000808 (builtins.fromJSON (builtins.readFile ./_volatile/router.ipv4.wan.json));
    };
  };
in let
  router = {
    managedNetworks = {
      ipv6 = {
        gua = ip.network.subnetAt site.ipv6.gua 64 (lib.fromHexString "0");
      };
    };

    ipv4 = {
      inherit (site.ipv4) wan;

      lan = ip.network.hostAddress site.ipv4.lan "0.0.0.1";
    };

    ipv6 = {
      ula = ip.network.hostAddress site.ipv6.ula "::e228:6dff:fe1d:8a9c";
    };
  };
in {
  inherit router;

  network = {
    inherit site;
  };

  hosts = {
    albedo = {
      ipv4 = {
        lan = ip.network.hostAddress site.ipv4.lan "0.0.0.3";
      };

      ipv6 = {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Subnet prefix was reused and Interface ID was generated randomly.
        # ────────────────────────────────────────────────────────────────────────
        # ´                      ┌──► openssl rand -hex 8 | fold -w4 | paste -sd:
        # ────────────────────────────────────────────────────────────────────────
        ula = ip.network.hostAddress site.ipv6.ula "::e567:df0a:5754:97ed";
      };
    };

    beidou = {
      managedNetworks = {
        ipv6 = {
          # ────────────────────────────────────────────────────────────────────────
          # NOTE: This prefix is broken off the ISP-provided static prefix. A static
          #       route is specified in the router's table.
          # ────────────────────────────────────────────────────────────────────────
          gua = ip.network.subnetAt site.ipv6.gua 64 (lib.fromHexString "c");
        };
      };

      ipv4 = {
        lan = ip.network.hostAddress site.ipv4.lan "0.0.0.2";
      };

      ipv6 = {
        gua = ip.network.hostAddress router.managedNetworks.ipv6.gua "::1:b03f:2f2a:c1df";

        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Subnet prefix was reused and Interface ID was generated randomly.
        # ────────────────────────────────────────────────────────────────────────
        # ´                      ┌──► openssl rand -hex 8 | fold -w4 | paste -sd:
        # ────────────────────────────────────────────────────────────────────────
        ula = ip.network.hostAddress site.ipv6.ula "::20:61fc:3462:bf01";
      };
    };
  };
}
