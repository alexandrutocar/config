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
              "127.0.0.1/8"
              "::1/128"
            ]
            ++ [
              "fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a/128"
            ];
        };
      };
    };
  };
}
