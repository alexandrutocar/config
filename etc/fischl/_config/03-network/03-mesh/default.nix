{lib, ...}: let
  inherit (lib.alias) radii;
in {
  services = {
    radii = {
      settings = {
        inherit (radii) site;
      };
    };
  };
}
