{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "a4205b50-197a-40c8-8057-fe1394630e91";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          intra = {
            ${mid} = {
              modules = recursive ./_config;
              nspawn = {
                config = {
                  filesConfig = {
                    Bind = [
                      "/state/var/lib/machines/${mid}/var/lib/n8n:/var/lib/n8n:idmap"
                      "/state/var/lib/machines/${mid}/var/lib/n8n.assets:/var/lib/n8n.assets:idmap"
                    ];
                  };
                };
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
                  target = config.services.sigil.settings.containers.intra.d86c8e1c-2bcd-4d2f-a3b2-7962afc28a51; # intra/automation/ollama
                }
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
        # { xxd -r -p <<< "$(systemd-id128 show "a4205b50197a40c88057fe1394630e91" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
