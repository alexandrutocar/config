{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
in {
  services.stalwart = {
    enable = true;
    settings = {
      "@type" = "PostgreSql";
      host = ip.wellKnown.ipv6.loopback |> ip.toCompressed;
      authSecret = {
        "@type" = "None";
      };
    };
  };

  environment.systemPackages = with pkgs; [stalwart-cli unzip];
}
