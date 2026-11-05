{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCompressed;
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
        Listen = networks.aether.internal.net.hosts.beidou |> toCompressed;

        Port = 8888;

        Allow = [
          config.services.sigil.settings.containers.intra."a4205b50-197a-40c8-8057-fe1394630e91".addresses.ula # intra/automation/n8n
        ];

        ConnectPort = [
          443 # HTTPS
        ];

        Filter = pkgs.writeTextFile {
          name = "filters";
          text = ''
            ^github\.com$
            ^api\.github\.com$
          '';
        };

        FilterExtended = true;

        FilterDefaultDeny = true;
      };
    };
  };
}
