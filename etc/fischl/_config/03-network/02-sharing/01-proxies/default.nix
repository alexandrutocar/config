{
  hostName,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [8888];
    };
  };

  services = {
    tinyproxy = {
      enable = true;

      settings = {
        Listen = radii.site.${hostName}.hostAddress |> ip.toCompressed;

        Port = 8888;

        Allow = let
          containers = shortPathToContainers config;
        in [
          (containers.porti.ea3680ca-4e51-4e86-b467-7f85d573834e |> getULA |> ip.toCompressed) # development/forge
        ];

        ConnectPort = [
          443 # HTTPS
          22 # SSH
        ];

        Filter = pkgs.writeTextFile {
          name = "filters";
          text = ''
            ^github\.com$
            ^api\.github\.com$
            ^codeload\.github\.com$
            ^gitlab\.com$
            ^codeberg\.org$
          '';
        };

        FilterExtended = true;

        FilterDefaultDeny = true;
      };
    };
  };
}
