{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "cf5c4ebc-4f33-4039-87e1-7b6c9b5baab9";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          porti = {
            ${mid} = {
              nspawn = {
                config = {
                  filesConfig = {
                    Bind = [
                      "/state/var/lib/machines/${mid}/var/lib/caddy:/var/lib/caddy:idmap"
                    ];
                  };
                };
                flags = mkAfter [
                  "--load-credential=credential.secret:%d/credential.secret"
                ];
              };
              modules = recursive ./_config;
            };
          };
        };

        network = {
          links = {
            porti = {
              ${mid} = [
                {
                  target = config.services.sigil.settings.containers.intra.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a; # intra/operation/dns
                }
              ];
            };
          };
        };
      };
    };
  };

  systemd.services."systemd-nspawn@${mid}" = {
    serviceConfig = {
      LoadCredentialEncrypted = [
        # { xxd -r -p <<< "$(systemd-id128 show "cf5c4ebc4f33403987e17b6c9b5baab9" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
