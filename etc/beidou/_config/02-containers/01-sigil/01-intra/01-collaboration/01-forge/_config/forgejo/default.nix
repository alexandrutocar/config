{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;
in {
  users.groups.git = {};

  users.users.git = {
    description = "Git";
    group = "git";
    home = "/var/lib/git";

    extraGroups = ["ssh"];

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
      enable = true;

      group = "git";
      user = "git";

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
