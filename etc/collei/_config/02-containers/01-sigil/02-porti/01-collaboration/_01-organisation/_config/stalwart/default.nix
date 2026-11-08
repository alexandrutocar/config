{
  pkgs,
  self,
  ...
}: let
  containers.beidou = {
    inherit (self.nixosConfigurations.beidou.config.services.sigil.settings.containers.porti) a8dd2ef7-86c8-4a7e-af8a-b3f98a2f31d3;
  };
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        8080 # HTTP
      ];
    };
  };

  services.stalwart = {
    enable = false;
    settings = {
      "@type" = "PostgreSql";
      host = containers.beidou.a8dd2ef7-86c8-4a7e-af8a-b3f98a2f31d3.addresses.ula;
      authSecret = {
        "@type" = "None";
      };
    };
  };

  environment.systemPackages = with pkgs; [stalwart-cli unzip];
}
