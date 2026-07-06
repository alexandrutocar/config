_: {
  systemd = {
    network = {
      networks = {
        "00-lo" = {
          matchConfig = {
            Name = "lo";
          };
          address =
            [
              "::1/128"
              "127.0.0.1/8"
            ]
            ++ [
              "fda0:9527:68ee:4f8a:46a1:b595:357f:c251/128"
            ];
        };
      };
    };
  };
}
