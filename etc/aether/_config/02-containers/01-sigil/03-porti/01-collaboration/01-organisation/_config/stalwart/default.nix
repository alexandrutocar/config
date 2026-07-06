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
      "@type" = "Sqlite";
      path = "/var/lib/stalwart/data.db";
    };
  };

  environment.systemPackages = with pkgs; [stalwart-cli unzip];
}
