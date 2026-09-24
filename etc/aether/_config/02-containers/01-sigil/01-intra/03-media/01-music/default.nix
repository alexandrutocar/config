{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "fecc0d40-eb4e-43d4-b0ef-c0627fcce582";
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
                    Bind =
                      [
                        "/archive/bibliotheca/music:/mnt/audio/music:idmap"
                        "/archive/bibliotheca/podcast:/mnt/audio/podcast:idmap"
                        "/archive/bibliotheca/playlists:/mnt/audio/playlists:idmap"
                      ]
                      ++ [
                        "/state/var/lib/machines/${mid}/var/lib/gonic/gonic.db:/var/lib/gonic/gonic.db:idmap"
                        "/state/var/lib/machines/${mid}/var/cache/gonic:/var/cache/gonic:idmap"
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
        # { xxd -r -p <<< "$(systemd-id128 show "fecc0d40eb4e43d4b0efc0627fcce582" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
