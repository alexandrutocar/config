_: {
  services.mimir = {
    enable = true;

    configuration = {
      common = {
        storage = {
          backend = "filesystem";
          filesystem.dir = "/var/lib/mimir";
        };

        server = {
          http_listen_address = "127.0.0.1";
          grpc_listen_address = "127.0.0.1";
        };
      };
    };
  };
}
