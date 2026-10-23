{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.modules) mkMerge;
  inherit (lib.strings) toInt;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [(toInt config.services.n8n.settings.port)];
    };
  };

  systemd = {
    services = {
      n8n = {
        serviceConfig = {
          ReadWritePaths = [
            config.services.n8n.settings.restrict-file-access-to
          ];
          SetCredentialEncrypted =
            config.systemd.services.n8n-task-runners.serviceConfig.SetCredentialEncrypted
            ++ (
              mkSetCredentialEncrypted {
                # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host --name=encryption-key - -
                encryption-key = ''
                  Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAACmOsk/OLphcaOG3IUAAAAAia3tOVlJ0ChJPpy
                  Dykd2e5u7i5ou8VxBgcmV/qfdOWs/W5Rzg+I6eZJx1cruTBG+bPxikB7Hfk6vcMy53rgrL0ZCk9qrej
                  JM5EZNjvej8y432Aa0zPrYET5xm6zdNNqHE+UfhIUwPGRsXITw1CsdRRLf1K6+sNWq
                '';
              }
            );
        };
      };
    };
  };

  services = {
    n8n = {
      enable = true;
      settings = mkMerge [
        {
          GENERIC_TIMEZONE = "Europe/Berlin";
          NODE_ENV = "production";
        }
        {
          listen-address = sigil.self.addresses.ula;
          proxy-hops = 1;
          host = "workflows.intra.net.internal";
          port = 8080;
          protocol = "https";
          editor-base-url = "https://workflows.intra.net.internal/";
        }
        {
          EXECUTIONS_DATA_PRUNE = true;
          EXECUTIONS_DATA_MAX_AGE = 2160;

          EXECUTIONS_DATA_SAVE_ON_ERROR = "all";
          EXECUTIONS_DATA_SAVE_ON_SUCCESS = "all";
        }
        {
          runners-task-timeout = 300;
          unverified-packages-enabled = false;
        }
        {
          templates-enabled = false;
          diagnostics-enabled = false;
          personalization-enabled = false;
          community-packages-enabled = false;
          version-notifications-enabled = false;
        }
        {
          default-binary-data-mode = "filesystem";
          restrict-file-access-to = "/var/lib/n8n.assets";
        }
        {
          encryption-key-file = "${credentialsDirectory "n8n"}/encryption-key";
          runners-auth-token-file = "${credentialsDirectory "n8n"}/runners-auth-token";
        }
      ];
    };
  };
}
