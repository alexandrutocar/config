{
  config,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra) ip;
  inherit (lib.extra.files.list) recursive;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
  inherit (lib.modules) mkAfter;
in let
  containers = shortPathToContainers config;

  target = containers.intra.${mid};

  mid = "e079b57e-4727-4408-8c33-39abaae975d9";
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
                  incoming = let
                    destinationAddresses = [(target |> getULA)];
                  in
                    # PORT-BY-PORT RULE
                    # -----------------
                    [
                      {
                        inherit destinationAddresses;

                        allowedTraffic = [
                          {
                            protocol = "tcp";
                            ports = [22];
                          }
                        ];

                        # ────────────────────────────────────────────────────────────────────────
                        # NOTE: Only Albedo may connect via SSH.
                        # ────────────────────────────────────────────────────────────────────────
                        sourceAddresses = let
                          allowedHosts = with networks.aether.internal.net.hosts; [albedo];
                        in
                          allowedHosts |> map ip.address.singleHostRoute;
                      }
                      {
                        inherit destinationAddresses;

                        allowedTraffic = [
                          {
                            protocol = "tcp";
                            ports = [80];
                          }
                        ];

                        # ────────────────────────────────────────────────────────────────────────
                        # NOTE: Only Keqing may need a .mobileconfig profile.
                        # ────────────────────────────────────────────────────────────────────────
                        sourceAddresses = let
                          allowedHosts = with networks.aether.internal.net.hosts; [keqing];
                        in
                          allowedHosts |> map ip.address.singleHostRoute;
                      }
                      {
                        inherit destinationAddresses;

                        allowedTraffic = [
                          {
                            protocol = "tcp";
                            ports = [443];
                          }
                        ];

                        sourceAddresses = let
                          allowedContainers = with containers.intra; [
                            a4205b50-197a-40c8-8057-fe1394630e91 # automation/n8n       ->  development/forge, automation/ollama
                            acda4bf3-2678-43c5-bae9-e67bd8cb710d # development/forge    ->  operation/auth
                            fe616e36-c9d0-4ba9-8938-436e75ef0dc0 # development/actions  ->  automation/workflows
                          ];
                          allowedHosts = with networks.aether.internal.net.hosts; [
                            albedo
                            beidou # nix  -> development/forge
                            keqing
                          ];
                        in
                          (allowedContainers |> map getULA) ++ (allowedHosts |> map ip.address.singleHostRoute);
                      }
                      {
                        inherit destinationAddresses;

                        allowedTraffic = [
                          {
                            protocol = "tcp";
                            ports = [8443];
                          }
                        ];

                        sourceAddresses = let
                          allowedContainers = with containers.intra; [
                            a4205b50-197a-40c8-8057-fe1394630e91 # automation/n8n       ->  automation/connections
                          ];
                          allowedHosts = with networks.aether.internal.net.hosts; [albedo];
                        in
                          (allowedContainers |> map getULA) ++ (allowedHosts |> map ip.address.singleHostRoute);
                      }

                      {
                        inherit destinationAddresses;

                        allowedTraffic = [
                          {
                            protocol = "tcp";
                            ports = [11434];
                          }
                        ];

                        sourceAddresses = let
                          allowedContainers = with containers.intra; [
                            a4205b50-197a-40c8-8057-fe1394630e91 # automation/n8n       ->  automation/ollama
                          ];
                          allowedHosts = with networks.aether.internal.net.hosts; [albedo keqing];
                        in
                          (allowedContainers |> map getULA) ++ (allowedHosts |> map ip.address.singleHostRoute);
                      }
                    ];
                };
              };
            };
          };
        };

        network = {
          links = {
            intra = {
              ${mid} = [
                {
                  target = config.services.sigil.settings.containers.intra.a8e714de-f158-49fc-958a-9176f25d2973; # intra/sharing/dav
                }
                {
                  target = config.services.sigil.settings.containers.intra.c38a828e-58a7-49af-894d-ba02f936d211; # intra/operation/auth
                }
                {
                  target = config.services.sigil.settings.containers.intra.acda4bf3-2678-43c5-bae9-e67bd8cb710d; # intra/development/forge
                }
                {
                  target = config.services.sigil.settings.containers.intra.a4205b50-197a-40c8-8057-fe1394630e91; # intra/automation/n8n
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
        # { xxd -r -p <<< "$(systemd-id128 show "e079b57e472744088c3339abaae975d9" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
