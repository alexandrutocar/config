{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "a8dd2ef7-86c8-4a7e-af8a-b3f98a2f31d3";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          porti = {
            ${mid} = {
              modules = recursive ./_config;
              nspawn = {
                config = {
                  filesConfig = {
                    Bind = [
                      "/state/var/lib/machines/${mid}/var/lib/postgresql:/var/lib/postgresql:idmap"
                      "/state/var/lib/machines/${mid}/var/lib/redis:/var/lib/redis:idmap"
                      "/state/var/lib/machines/${mid}/var/lib/stalwart:/var/lib/stalwart:idmap"
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
      };
    };
  };

  systemd.services."systemd-nspawn@${mid}" = {
    serviceConfig = {
      LoadCredentialEncrypted = [
        # { xxd -r -p <<< "$(systemd-id128 show "a8dd2ef786c84a7eaf8ab3f98a2f31d3" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
