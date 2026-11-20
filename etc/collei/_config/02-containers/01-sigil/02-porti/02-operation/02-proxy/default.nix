{
  config,
  self,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.extra.sigil) getGUA getULA shortPathToContainers;
  inherit (lib.modules) mkAfter;
in let
  fischlContainers = shortPathToContainers self.nixosConfigurations.fischl.config;

  containers = shortPathToContainers config;

  target = containers.porti.${mid};

  mid = "c8ac5cd5-7563-4e68-9dce-68bb11224eab";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          porti = {
            ${mid} = {
              addresses = {
                ipv6 = {
                  extra = {
                    gua = {
                      forge = "::f2c8:fd9a:f7ba:0c09";
                    };
                  };
                };
              };

              modules = recursive ./_config;

              nspawn = {
                settings = {
                  Files = {
                    Bind = [
                      "/state/var/lib/machines/${mid}/var/lib/caddy:/var/lib/caddy:idmap"
                    ];
                  };
                };
                flags = mkAfter [
                  "--load-credential=credential.secret:%d/credential.secret"
                ];
              };

              rules = {
                networkTraffic = {
                  incoming = let
                    sourceAddresses = ["::/0"];
                  in [
                    {
                      inherit sourceAddresses;

                      destinationAddresses = [
                        (target |> getGUA)
                      ];

                      allowedTraffic = [
                        {
                          protocol = "tcp";
                          ports = [80 443];
                        }
                        {
                          protocol = "udp";
                          ports = [443];
                        }
                      ];
                    }
                    {
                      inherit sourceAddresses;

                      destinationAddresses = [target.addresses.ipv6.extra.gua.forge];

                      allowedTraffic = [
                        {
                          protocol = "tcp";
                          ports = [443 22];
                        }
                        {
                          protocol = "udp";
                          ports = [443];
                        }
                      ];
                    }
                    {
                      destinationAddresses = [(target |> getULA)];

                      allowedTraffic = [
                        {
                          protocol = "tcp";
                          ports = [443];
                        }
                        {
                          protocol = "udp";
                          ports = [443];
                        }
                      ];

                      sourceAddresses = let
                        allowedContainers =
                          (with fischlContainers; [
                            porti.ea3680ca-4e51-4e86-b467-7f85d573834e
                          ])
                          |> map getULA;
                      in
                        allowedContainers;
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
        # { xxd -r -p <<< "$(systemd-id128 show "c8ac5cd575634e689dce68bb11224eab" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
