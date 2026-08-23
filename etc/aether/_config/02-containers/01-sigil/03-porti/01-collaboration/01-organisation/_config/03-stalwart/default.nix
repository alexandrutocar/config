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
      host = "::1";
      authSecret = {
        "@type" = "None";
      };
    };
  };

  environment.systemPackages = with pkgs; [stalwart-cli unzip];
}
