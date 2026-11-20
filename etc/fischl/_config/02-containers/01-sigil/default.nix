{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
in {
  services.sigil = {
    enable = true;

    settings = {
      network = {
        inherit (radii.site.${hostName}) hostAddress;

        ula = {
          inherit (radii.site.${hostName}) prefix;
        };
      };
    };
  };
}
