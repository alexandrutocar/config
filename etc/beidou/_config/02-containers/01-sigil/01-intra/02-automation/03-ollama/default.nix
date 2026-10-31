{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "d86c8e1c-2bcd-4d2f-a3b2-7962afc28a51";
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
                    Bind =
                      [
                        "/state/var/lib/machines/${mid}/var/lib/models:/var/lib/models:idmap"
                      ]
                      ++ [
                        "/dev/nvidiactl"
                        "/dev/nvidia0"
                        "/dev/nvidia-uvm"
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
        # { xxd -r -p <<< "$(systemd-id128 show "d86c8e1c2bcd4d2fa3b27962afc28a51" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
      DeviceAllow = [
        "/dev/nvidiactl rw"
        "/dev/nvidia0 rw"
        "char-nvidia-uvm rw"
      ];
    };
  };
}
