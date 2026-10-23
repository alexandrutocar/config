{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "b6cab864-64cc-454d-8647-30348af279da";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          intra = {
            ${mid} = {
              modules = recursive ./_config;
              nspawn = {
                flags = mkAfter [
                  "--load-credential=credential.secret:%d/credential.secret"
                ];
              };
            };
          };
        };
        network = {
          links = {
            intra = {
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
        # { xxd -r -p <<< "$(systemd-id128 show "b6cab86464cc454d864730348af279da" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
