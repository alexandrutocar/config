{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "acda4bf3-2678-43c5-bae9-e67bd8cb710d";
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
                      "/state/var/lib/machines/${mid}/var/lib/forgejo:/var/lib/forgejo:idmap"
                      "/state/var/lib/machines/${mid}/etc/ssh/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key:idmap"
                      "/state/var/lib/machines/${mid}/etc/ssh/ssh_host_ed25519_key.pub:/etc/ssh/ssh_host_ed25519_key.pub:idmap"
                      "/state/var/lib/machines/${mid}/etc/ssh/ssh_host_rsa_key:/etc/ssh/ssh_host_rsa_key:idmap"
                      "/state/var/lib/machines/${mid}/etc/ssh/ssh_host_rsa_key.pub:/etc/ssh/ssh_host_rsa_key.pub:idmap"
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
        # { xxd -r -p <<< "$(systemd-id128 show "acda4bf3267843c5bae9e67bd8cb710d" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
