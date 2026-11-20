{
  config,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
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
                            ports = [80];
                          }
                        ];

                        # ────────────────────────────────────────────────────────────────────────
                        # NOTE: Only Keqing may need a .mobileconfig profile.
                        # ────────────────────────────────────────────────────────────────────────
                        sourceAddresses = let
                          allowedHosts =
                            (with radii.site; [
                              keqing
                            ])
                            |> map (h: h.hostAddress);
                        in
                          allowedHosts;
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
                          allowedContainers =
                            (with containers.intra; [
                              a4205b50-197a-40c8-8057-fe1394630e91 # automation/n8n       ->  automation/ollama
                            ])
                            |> map getULA;

                          allowedHosts =
                            (with radii.site; [
                              albedo
                              keqing
                            ])
                            |> map (h: h.hostAddress);
                        in
                          allowedContainers ++ allowedHosts;
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
                          allowedContainers =
                            (with containers.intra; [
                              a4205b50-197a-40c8-8057-fe1394630e91 # automation/n8n       ->  automation/connections
                            ])
                            |> map getULA;
                          allowedHosts =
                            (with radii.site; [
                              albedo
                            ])
                            |> map (h: h.hostAddress);
                        in
                          allowedContainers ++ allowedHosts;
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
                          allowedContainers =
                            (with containers.intra; [
                              a4205b50-197a-40c8-8057-fe1394630e91 # automation/n8n       ->  automation/ollama
                            ])
                            |> map getULA;

                          allowedHosts =
                            (with radii.site; [
                              albedo
                              keqing
                            ])
                            |> map (h: h.hostAddress);
                        in
                          allowedContainers ++ allowedHosts;
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
        # { xxd -r -p <<< "$(systemd-id128 show "e079b57e472744088c3339abaae975d9" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
