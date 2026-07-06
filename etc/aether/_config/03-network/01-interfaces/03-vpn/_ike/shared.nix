_: {
  options = {
    extra.virtual-private-network.ike-ipsec = let
      # Network
      domain = "host.internal";
      prefix = "fd31::1:0/112";

      # Peers
      circle = [
        "aether"
        "albedo"
        "keqing"
        "lumine"
      ];
      anchor = builtins.head circle;
      spokes = builtins.tail circle;
    in {
      config = {
        # Network
        inherit domain prefix;

        # Peers
        inherit anchor circle spokes;
      };
      lib = {
        mkFQDN = peer: "${peer}.${domain}";
        mkAddr = peer: let
          host = let
            hash = builtins.hashString "sha256" peer;
          in "${builtins.substring 0 4 hash}";
        in "fd31::1:${host}";
      };
    };
  };
}
