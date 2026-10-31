{
  config,
  pkgs,
  ...
}: {
  networking = {
    firewall = {
      allowedTCPPorts = [8888];
    };
  };

  services = {
    tinyproxy = {
      enable = true;

      settings = {
        Listen = "fda0:9527:68ee:4f8a:f7f3:176c:41e0:4098";

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
