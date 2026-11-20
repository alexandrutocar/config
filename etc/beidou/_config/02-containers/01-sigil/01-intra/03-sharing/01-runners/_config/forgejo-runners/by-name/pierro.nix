{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
  inherit (lib.extra) url;
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
in {
  services.forgejo-runner.instances = {
    pierro = {
      enable = true;
      settings = {
        container = {
          network = "host";
          options = "-v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro";
          valid_volumes = ["/etc/ssl/certs/ca-certificates.crt"];
        };

        runner = {
          labels = [
            "host:host"
          ];
          envs = {
            HTTPS_PROXY = url.mkOrigin "http" radii.site.beidou.hostAddress 8888;
            NO_PROXY = "forge.ueuie.earth,workflows.intra.net.internal";
            NIX_CONFIG = "experimental-features = ca-derivations flakes nix-command parse-toml-timestamps pipe-operators";
          };
        };

        server = {
          connections = {
            default = {
              token_url = "file:${credentialsDirectory "forgejo-runner-pierro"}/token";
              url = "https://forge.ueuie.earth";
              uuid = "7b67c9da-755c-41fc-bee7-1ae134e2fb39";
            };
          };
        };
      };
    };
  };

  systemd.services = {
    forgejo-runner-pierro = {
      path = with pkgs; [
        config.nix.package
        nodejs-slim
        jq
        curl
        skopeo
        diffutils
        gitMinimal
      ];

      serviceConfig = {
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # echo -n '<token>' | systemd-creds encrypt --with-key=host --name=token - -
          token = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAA3HGk0jo60mlUoWTAAAAAATPx7s9kJTW+9I7j
            enRl24XtmjKW11ZPgjELC9JFZ4ng73lxaXNy/Dey0TrCOorRDYKABdSptTRo4BURDdWXIVzMWNfG1Eu
            3U+zE2+EKA8ZodhPbfAf08ng==
          '';
        };
      };
    };
  };
}
