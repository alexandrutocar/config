{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.ip) toCompressed wellKnown;
in {
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
      host = wellKnown.ipv6.loopback |> toCompressed;
      authSecret = {
        "@type" = "None";
      };
    };
  };

  environment.systemPackages = with pkgs; [stalwart-cli unzip];
}
