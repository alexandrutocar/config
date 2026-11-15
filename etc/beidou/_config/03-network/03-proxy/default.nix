{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra) ip;
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
        Listen = networks.aether.internal.net.hosts.beidou |> ip.toCompressed;

        Port = 8888;

        Allow = let
          allowList = with config.services.sigil.settings.containers.intra; [
            a4205b50-197a-40c8-8057-fe1394630e91.addresses.ipv6.ula # intra/automation/n8n
            fe616e36-c9d0-4ba9-8938-436e75ef0dc0.addresses.ipv6.ula # intra/development/actions
          ];
        in
          allowList |> map ip.toCompressed;

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
