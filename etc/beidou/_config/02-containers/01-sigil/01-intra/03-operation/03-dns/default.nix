{
  config,
  lib,
  ...
}: let
  inherit (lib.extra) url;
  inherit (lib.extra.files.list) recursive;
  inherit (lib.extra.sigil) getConfig getULA shortPathToContainers;
  inherit (lib.extra.trivial) mapPipeline;
  inherit (lib.modules) mkAfter;
in let
  targetConfig = getConfig target;

  containers = shortPathToContainers config;

  target = containers.intra.${mid};

  mid = "cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          intra = {
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
                      destinationAddresses = [(target |> getULA)];

                      allowedTraffic = let
                        ports = targetConfig.services.unbound.settings.server.interface |> mapPipeline (with url.interface; [fromNLnetLabs getPort]);
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

                      sourceAddresses = import ./_config/unbound/_facts/rules/incoming.nix {
                        inherit containers lib;
                      };
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
        # { xxd -r -p <<< "$(systemd-id128 show "cd4e799127fc425b9f9ca0b3ec1b4f1a" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
