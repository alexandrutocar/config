{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;
in let
  group = "git";
  user = "git";
in {
  users.groups.${group} = {};

  users.users.${user} = {
    inherit group;

    home = "/var/lib/${user}";

    extraGroups = [
      config.users.groups.ssh.name
    ];

    createHome = true;
    isSystemUser = true;
    useDefaultShell = true;
  };

  networking = {
    firewall = {
      allowedTCPPorts = [
        config.services.forgejo.settings.server.HTTP_PORT
      ];
    };
  };

  services = {
    forgejo = {
      inherit group user;

      enable = true;

      settings = {
        "service.explore" = {
          REQUIRE_SIGNIN_VIEW = true;
        };

        service = {
          DISABLE_REGISTRATION = true;
        };

        security = {
          DISABLE_QUERY_AUTH_TOKEN = true;
        };

        server = mkMerge [
          {
            ROOT_URL = "https://forge.dev.intra.net.internal";
            DOMAIN = "forge.dev.intra.net.internal";
          }
          {
            HTTP_ADDR = sigil.self.addresses.ula;
            HTTP_PORT = 8080;
          }
          {
            SSH_CREATE_AUTHORIZED_KEYS_FILE = false;
          }
        ];
      };
    };
  };
}
