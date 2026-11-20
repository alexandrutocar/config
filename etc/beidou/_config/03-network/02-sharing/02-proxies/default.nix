{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
  inherit (lib.extra.trivial) mapPipeline;
  inherit (lib.strings) concatStringsSep;
in let
  beidouContainers = shortPathToContainers config;
in let
  Allow =
    (with beidouContainers.intra; [
      a4205b50-197a-40c8-8057-fe1394630e91 # intra/automation/n8n
    ])
    |> mapPipeline [getULA ip.toCompressed];

  Port = 8888;
in {
  networking = {
    firewall = {
      # Only the proxy's clients reach its port; tinyproxy's Allow checks
      # them again.
      extraInputRules = ''
        ip6 saddr { ${concatStringsSep ", " Allow} } tcp dport ${toString Port} accept
      '';
    };
  };

  services = {
    tinyproxy = {
      enable = true;

      settings = {
        inherit Allow Port;

        Listen = radii.site.beidou.hostAddress |> ip.toCompressed;

        ConnectPort = [
          443 # HTTPS
        ];

        Filter = pkgs.writeTextFile {
          name = "filters";
          text = ''
            ^github\.com$
            ^api\.github\.com$
            ^codeload\.github\.com$
          '';
        };

        FilterExtended = true;

        FilterDefaultDeny = true;
      };
    };
  };
}
