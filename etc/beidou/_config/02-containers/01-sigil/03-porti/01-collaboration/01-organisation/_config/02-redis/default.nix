{config, ...}: {
  networking = {
    firewall = {
      allowedTCPPorts = [
        config.services.redis.port
      ];
    };
  };

  services = {
    redis = {
      enable = true;

      bind = "::";
    };
  };
}
