{pkgs, ...}: {
  networking = {
    firewall = {
      allowedTCPPorts = [
        8080 # HTTP
      ];
    };
  };

  services.stalwart = {
    enable = true;
    settings = {
      "@type" = "PostgreSql";
      host = "fda0:9527:68ee:9cfe:7d2e:1a54:f290:09a3";
      authSecret = {
        "@type" = "None";
      };
    };
  };

  environment.systemPackages = with pkgs; [stalwart-cli unzip];
}
