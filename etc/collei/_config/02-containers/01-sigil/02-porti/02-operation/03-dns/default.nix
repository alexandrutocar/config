{
  config,
  lib,
  ...
}: let
  inherit (lib.extra) url;
  inherit (lib.extra.files.list) recursive;
  inherit (lib.extra.sigil) getConfig getGUA shortPathToContainers;
  inherit (lib.extra.trivial) pipeline;
  inherit (lib.modules) mkAfter;
in let
  targetConfig = getConfig target;

  containers = shortPathToContainers config;

  target = containers.porti.${mid};

  mid = "baa45f8a-4c43-41ed-bcc6-5365c1c4a555";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          porti = {
            ${mid} = {
              modules = recursive ./_config;

              nspawn = {
                flags = mkAfter [
                  "--load-credential=credential.secret:%d/credential.secret"
                ];
              };

              rules = {
                networkTraffic = {
                  incoming = [
                    {
                      destinationAddresses = [(target |> getGUA)];

                      allowedTraffic = let
                        ports = targetConfig.services.nsd.settings.server.interface |> map (pipeline (with url.interface; [fromNLnetLabs getPort]));
                      in [
                        {
                          protocol = "tcp";
                          inherit ports;
                        }
                        {
                          protocol = "udp";
                          inherit ports;
                        }
                      ];

                      sourceAddresses = ["::/0"];
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
        # { xxd -r -p <<< "$(systemd-id128 show "baa45f8a4c4341edbcc65365c1c4a555" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
