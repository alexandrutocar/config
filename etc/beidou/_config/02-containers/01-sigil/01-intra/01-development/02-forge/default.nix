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
                settings = {
                  Files = {
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

              rules = {
                networkTraffic = {
                  incoming = [
                    {
                      destinationAddresses = [(target |> getULA)];

                      allowedTraffic = [
                        {
                          protocol = "tcp";
                          ports =
                            [
                              targetConfig.services.forgejo.settings.server.HTTP_PORT
                            ]
                            ++ targetConfig.services.openssh.ports;
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
        # { xxd -r -p <<< "$(systemd-id128 show "acda4bf3267843c5bae9e67bd8cb710d" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
