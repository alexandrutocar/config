_: {
  services.sigil = {
    enable = true;

    settings = {
      network = {
        # Prefix 2a01:4f80:c0c0:6870::/64 has been provided as is by Hetzner.
        gua.prefix = "2a01:04f8:0c0c:0687";

        ula = {
          # Prefix fd + a0:9527:68ee is generated randomly. The fourth hextet is
          # derived from the zone name, yielding one deterministic /64 per zone.
          prefix = "fda0:9527:68ee";
          source = "fda0:9527:68ee:4f8a:46a1:b595:357f:c251";
        };
      };
    };
  };
}
