{
  config,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
in let
  containers = shortPathToContainers config;

  target = containers.porti.${mid};
  mid = "c7f4d370-8043-46c8-97ae-39417237ac82";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          porti = {
            ${mid} = {
              modules = recursive ./_config;

              nspawn = {
                settings = {
                  Files = {
                    Bind = [
                      "/state/var/lib/machines/${mid}/var/lib/stalwart:/var/lib/stalwart:idmap"
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
                            8080 # HTTP (Stalwart)
                          ];
                        }
                      ];

                      sourceAddresses = let
                        allowedHosts =
                          (with radii.site; [
                            albedo
                            keqing
                          ])
                          |> map (h: h.hostAddress);
                      in
                        allowedHosts;
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
        # { xxd -r -p <<< "$(systemd-id128 show "c7f4d370804346c897ae39417237ac82" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
