{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "e079b57e-4727-4408-8c33-39abaae975d9";
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
                  target = config.services.sigil.settings.containers.intra.a8e714de-f158-49fc-958a-9176f25d2973; # intra/collaboration/dav
                }
                {
                  target = config.services.sigil.settings.containers.intra.c38a828e-58a7-49af-894d-ba02f936d211; # intra/operation/auth
                }
                {
                  target = config.services.sigil.settings.containers.intra.acda4bf3-2678-43c5-bae9-e67bd8cb710d; # intra/collaboration/forge
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
        # { xxd -r -p <<< "$(systemd-id128 show "e079b57e472744088c3339abaae975d9" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
