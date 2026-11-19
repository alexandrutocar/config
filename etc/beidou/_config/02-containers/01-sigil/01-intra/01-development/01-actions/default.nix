{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "fe616e36-c9d0-4ba9-8938-436e75ef0dc0";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          intra = {
            ${mid} = {
              modules = recursive ./_config;

              nspawn = {
                settings = {
                  Files = {
                    Bind = [
                      "/state/var/lib/machines/${mid}/var/lib/containers:/var/lib/containers:idmap"
                    ];
                    BindReadOnly = [
                      "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
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
        # { xxd -r -p <<< "$(systemd-id128 show "fe616e36c9d04ba98938436e75ef0dc0" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
