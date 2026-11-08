{config, ...}: {
  networking = {
    firewall = {
      allowedTCPPorts = [
        config.services.redis.servers.stalwart.port
      ];
    };
  };

  services = {
    redis = {
      servers = {
        stalwart = {
          enable = true;

          bind = "::";
        };
      };
    };
  };
}
