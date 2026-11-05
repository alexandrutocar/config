lib: let
  inherit (lib.extra.ip.network) fromCIDR hostAddress subnetAt;
  inherit (lib.attrsets) mergeAttrsList;
in {
  internal.net = let
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: This is a site prefix as described in Section 3.2 of RFC4193. The
    #       following command can be used to generate a pseudo-random prefix:
    #
    #       ```sh
    #       echo -n "fd$(openssl rand -hex 5)" | fold -w4 | paste -sd:
    #       ```
    #
    #       See https://www.rfc-editor.org/info/rfc4193/#section-3.2.
    # ────────────────────────────────────────────────────────────────────────
    _global = fromCIDR 6 "fda0:9527:68ee::/48";
    network = _global;
  in
    mergeAttrsList [
      {
        _meta = {
          inherit network;
        };
      }
      {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: hosts.net.internal
        # ────────────────────────────────────────────────────────────────────────
        hosts = let
          # ────────────────────────────────────────────────────────────────────────
          # NOTE: Subnet ID together with site prefix forms a subnet prefix. It can
          #       be chosen at random, just like the site prefix:
          #
          #       ```sh
          #       openssl rand -hex 2
          #       ```
          #
          #       See https://www.rfc-editor.org/info/rfc4193/#section-3.1.
          # ────────────────────────────────────────────────────────────────────────
          _subnet = subnetAt _global 64 (lib.fromHexString "4f8a");
          network = _subnet;
        in
          mergeAttrsList [
            # Network Details
            # ---------------
            {
              _meta = {
                inherit network;
              };
            }
            # Host Interfaces
            # ---------------
            {
              albedo = hostAddress _subnet "::ad9c:4066:9123:5d9a";
              beidou = hostAddress _subnet "::f7f3:176c:41e0:4098";
              collei = hostAddress _subnet "::46a1:b595:357f:c251";
              fischl = hostAddress _subnet "::712a:ed72:b041:27c3";
              keqing = hostAddress _subnet "::afbf:7002:aa5f:a363";
            }
          ];
      }
      {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: inter.net.internal
        # ────────────────────────────────────────────────────────────────────────
        inter = let
          # ────────────────────────────────────────────────────────────────────────
          # NOTE: See Subnet-ID.
          # ────────────────────────────────────────────────────────────────────────
          _subnet = subnetAt _global 64 (lib.fromHexString "c84c");
        in {
          network = _subnet;
        };
      }

      {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: intra.net.internal
        # ────────────────────────────────────────────────────────────────────────
        intra = let
          # ────────────────────────────────────────────────────────────────────────
          # NOTE: See Subnet-ID.
          # ────────────────────────────────────────────────────────────────────────
          _subnet = subnetAt _global 64 (lib.fromHexString "f1b6");
        in {
          network = _subnet;
        };
      }
    ];
}
