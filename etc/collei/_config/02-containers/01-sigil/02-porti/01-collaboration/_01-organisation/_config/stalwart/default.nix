{
  pkgs,
  self,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA shortPathToContainers;

  beidouContainers = shortPathToContainers self.nixosConfigurations.beidou.config;
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
      host = beidouContainers.porti.a8dd2ef7-86c8-4a7e-af8a-b3f98a2f31d3 |> getULA |> ip.toCompressed;
      authSecret = {
        "@type" = "None";
      };
    };
  };

  environment.systemPackages = with pkgs; [stalwart-cli unzip];
}
