{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.extra.sigil) getConfig getULA shortPathToContainers;
  inherit (lib.modules) mkAfter;
in let
  targetConfig = getConfig target;

  containers = shortPathToContainers config;

  target = containers.intra.${mid};

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

              rules = {
                networkTraffic = {
                  incoming = [
                    {
                      destinationAddresses = [(target |> getULA)];

                      allowedTraffic = [
                        {
                          protocol = "tcp";
                          ports = [
                            targetConfig.services.ollama.port
                          ];
                        }
                      ];

                      sourceAddresses = [(containers.intra.e079b57e-4727-4408-8c33-39abaae975d9 |> getULA)];
                    }
                  ];
                };
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
