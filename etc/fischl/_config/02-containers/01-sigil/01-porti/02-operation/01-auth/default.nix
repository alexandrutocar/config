{
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.extra.files.list) recursive;
  inherit (lib.extra.sigil) getConfig getULA shortPathToContainers;
  inherit (lib.modules) mkAfter mkMerge;
  inherit (lib.meta) getExe;
in let
  targetConfig = getConfig target;

  containers = shortPathToContainers config;

  target = containers.porti.${mid};

  mid = "c4a54e9b-fab6-4f57-ad12-3cfc34c950ab";
in let
  state = let
    container = "/state/var/lib/machines/${mid}";
  in {
    inherit container;

    services = {
      pocket-id = "${container}/var/lib/pocket-id";
    };
  };

  backup = let
    name = mid;
  in {
    repository = {
      sftp = {
        host = "u542221-sub2.your-storagebox.de";
        port = 23;
        user = "u542221-sub2";
        path = "/home/backup";
      };
    };

    inherit name;

    serviceName = "restic-backups-${name}";
  };
in {
  programs.ssh.knownHosts.${backup.repository.sftp.host} = {
    hostNames = with backup.repository.sftp; ["[${host}]:${toString port}"];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
  };

  services = {
    restic = {
      backups = {
        ${backup.name} = let
          staging = "${state.container}/.backup";
        in
          mkMerge [
            {
              # Preparation
              # -----------
              backupPrepareCommand = ''
                rm -rf ${staging}
                install -d -m 700 ${staging}

                # Pocket-ID
                # ---------
                ${getExe pkgs.sqlite} ${state.services.pocket-id}/pocket-id.db ".backup '${staging}/pocket-id.db'"
              '';

              backupCleanupCommand = ''
                rm -rf ${staging}
              '';
            }
            {
              # Repository
              # ----------
              repository = with backup.repository.sftp; "sftp:${user}@${host}:${path}";

              initialize = true;

              # Authorization
              # -------------
              passwordFile = "${credentialsDirectory backup.serviceName}/password";

              extraOptions = with backup.repository.sftp; [
                "sftp.command='ssh ${user}@${host} -p ${toString port} -o IdentitiesOnly=yes -i ${credentialsDirectory backup.serviceName}/${user}@${host} -s sftp'"
              ];
            }
            {
              # Backup Configuration
              # --------------------
              paths = [
                staging
                state.services.pocket-id
              ];

              exclude = [
                # ──────────────────────────────────────────────────────────────────────
                # NOTE: SQLite database is backed-up online using specialised tools.
                #       See: 'backupPrepareCommand'.
                # ──────────────────────────────────────────────────────────────────────
                "${state.services.pocket-id}/pocket-id.db"
                "${state.services.pocket-id}/pocket-id.db-wal"
                "${state.services.pocket-id}/pocket-id.db-shm"
              ];

              timerConfig = {
                OnCalendar = "hourly";
                RandomizedDelaySec = "5m";
                Persistent = true;
              };

              extraBackupArgs = [
                # ────────────────────────────────────────────────────────────────────────
                # NOTE: Backup should not congest uplink. This is a temporary solution.
                # ────────────────────────────────────────────────────────────────────────
                "--limit-upload 1024"
              ];
            }
            {
              # Maintenance/Pruning
              # -------------------
              pruneOpts = [
                "--keep-hourly 48"
                "--keep-daily 14"
                "--keep-weekly 8"
                "--keep-monthly 12"
                "--keep-yearly 3"
              ];
            }
          ];
      };
    };

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
                      "${state.services.pocket-id}:/var/lib/pocket-id:idmap"
                    ];
                  };
                };

                flags = mkAfter [
                  "--load-credential=credential.secret:%d/credential.secret"
                ];
              };

              rules = {
                networkTraffic = let
                  colleiContainers = shortPathToContainers self.nixosConfigurations.collei.config;
                in {
                  incoming = [
                    {
                      destinationAddresses = [(target |> getULA)];

                      allowedTraffic = [
                        {
                          protocol = "tcp";
                          ports = [
                            targetConfig.services.pocket-id.settings.PORT
                          ];
                        }
                      ];

                      sourceAddresses = [(colleiContainers.porti.c8ac5cd5-7563-4e68-9dce-68bb11224eab |> getULA)];
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

  systemd.services = {
    ${backup.serviceName} = {
      serviceConfig = {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Backup should not take up tpp many resources.
        # ────────────────────────────────────────────────────────────────────────
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";

        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host+tpm2 --name=password - -
          "password" = ''
            FBQliBiiQM2QC86GLbXHuSAAAAABAAAADAAAABAAAAD8I96/yd54w0uozF8AAAAAAAAAAAAAAAALAAE
            A8AAAACAAAAAAngAgK4i3e19YM2l3281HX3ip4JVSSdGC7Cz0dnPyXTZPy00AEEJfRQjwo7IUJ10p/E
            WRJBfLnNRzZBrK9NgHqOrfbMsZYfq96LDYDvuvGPRqgqosMEXUKJCjIPKCU/G6YUuzgD2HDm+F3bhYJ
            Zti+2goCQN78BzfCC54VLPBAgd6q2cnO0qckNa2QYJBiud7QyIIr9snxEBzPJ+ml2CTAE4ACAALAAAE
            EgAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAgXCddxMljw7/3K6JEDDwS0MqEeJR
            7V9pT7Osjo39gnEYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIAQAAgQAAAQAiAA
            vuAJGu9FG/Eb+WYnnVLQXm3zjWOfik0jijrtS8Ce3x5QAAAAEBGgABAAsAAwRyAAAABgCAAEMAEAgAA
            AAAAAEA1Q9Nxt85tUmGkPRycTFNNg4hKxomyu6kSN5zdOjY7ayDd6VguqHOJlGF4ehVVB7rmLqjWK5H
            zBU5rG+Y7/V9nJ+7GH2WyQ9Jsz5XNw0wRW4Q5vqUPw5Lp5Sw2zXfKjHQNe7DpkGc9CPMJmSUAlKuCWs
            HJPbGKI+gAYMxLO3Lkx/0J2Bej8AT1Ig4pZTtlIUw7IG4sF7WyoUQjI4GHoeepVkOuz+NBHEyRFd5B0
            +1s+JqDguP/+1hbE8lDXglH1xGZQtzmmjZTO/CzyyTw4It8JbnO11EkRXT69+xE2gB1WfWhP3EGWmVO
            4ue3atJ+wGSP+CnysQh6gpLM9qT0tOAHQAAAABM8X3oH6ELutf9C+ImL9XovedgW0XUYBZehWsYBVbi
            sopTkBh9CsiKRSCuPV4SBnZcEs3Q0EesLG+pN9aDvkF6bimux3cxzOeGacpYmefONsk7o3s70oA5EG9
            dH/ndry+snfUSveGMlR9Tj4NKJjZ/
          '';
          # cat /tmp/u542221-sub2@u542221-sub2.your-storagebox.de | systemd-creds encrypt --with-key=host+tpm2 --name=u542221-sub2@u542221-sub2.your-storagebox.de - -
          "u542221-sub2@u542221-sub2.your-storagebox.de" = ''
            FBQliBiiQM2QC86GLbXHuSAAAAABAAAADAAAABAAAADi+kwGqKElOljI98IAAAAAAAAAAAAAAAALAAE
            A8AAAACAAAAAAngAgoy1YGI12VB7JWAIwvWGbXVmZ6aLKYml9dUIBXCZz9+IAEDuKNducf3NKnliPaK
            +hOgtxi6kVT9lrg/rfkMKOQ62nPkBLPAzn5txN6iL9Hvio5Pe1dtR5e89eSUpb6CMyBH/JJf4EeRJsf
            YAiwyV6Rkrtv1QitGIYS2MNdzooOvKSltb37QPADCsu0pwZiwtPmFn2UMgYdKfI+O41AE4ACAALAAAE
            EgAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAg2GkUetWzsvFlgkF3SuWAjXMDHTb
            LvsmK6zoiCBlF3Q4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIAQAAgQAAAQAiAA
            vuAJGu9FG/Eb+WYnnVLQXm3zjWOfik0jijrtS8Ce3x5QAAAAEBGgABAAsAAwRyAAAABgCAAEMAEAgAA
            AAAAAEA1Q9Nxt85tUmGkPRycTFNNg4hKxomyu6kSN5zdOjY7ayDd6VguqHOJlGF4ehVVB7rmLqjWK5H
            zBU5rG+Y7/V9nJ+7GH2WyQ9Jsz5XNw0wRW4Q5vqUPw5Lp5Sw2zXfKjHQNe7DpkGc9CPMJmSUAlKuCWs
            HJPbGKI+gAYMxLO3Lkx/0J2Bej8AT1Ig4pZTtlIUw7IG4sF7WyoUQjI4GHoeepVkOuz+NBHEyRFd5B0
            +1s+JqDguP/+1hbE8lDXglH1xGZQtzmmjZTO/CzyyTw4It8JbnO11EkRXT69+xE2gB1WfWhP3EGWmVO
            4ue3atJ+wGSP+CnysQh6gpLM9qT0tOAHQAAAAB03+AuJgNefnK2CiPyn7IoFV+uy+jCUl/G/6e9kTny
            f54RTHi93xsC2pyB5LYm58gmyDlcFvoHIxrx6boNnxr4QtHLGI94ouV9yayJ2M9DylW/rjwW+49QTkj
            aNdEKDmRHJuHPd0rQbhAcwbl6w8aeZjwTomhgDWjQIzM/n1bFTC8gK76y4u/0nvt/Q8SNhig+4XJnXr
            iFBubesCIUriKPUGMhmJUSyqTw/LXli8y50GDNjLs/TQwaEj/a5DxgyBxU5nS2AMGOOr0OpmFVJfmmV
            l1fcZWPKIPTNOUvJj8FxiCSsFrRPpN63w7bhGwcBP6XGkTkc3ixty6FBJe59XJLw7xv0N7cjLdVzOqk
            k0WZ6oGGtcX5PtToisMbK1vMnNw/iODj7ZTOJ+otrowDynESCDI6WQuK0bUNJGIIjqbvYSEqb0FY2Eq
            gIq/Xh87Uk6eEbXoHtF0sLlvgxD3G4RSMXFAcqbGWkwz8iZtLnif+06VNhcgJbMS15wzra6n6NuRIx7
            4++IcuFdBFj7FwAnJVADjHi+TVJ92CvqpU4WImOOre4GbD4nvWbS9RJxzU3bkW1BAJNjGyANaplR1JW
            GJIZkrc3s48uj+6PDDO+I8zqrI63ThJt6UwJn6f85NgAA==
          '';
        };
      };
    };

    "systemd-nspawn@${mid}" = {
      serviceConfig = {
        LoadCredentialEncrypted = [
          # { xxd -r -p <<< "$(systemd-id128 show "c4a54e9bfab64f57ad123cfc34c950ab" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
          "credential.secret:${./_secret/credential.secret.encrypted}"
        ];
      };
    };
  };
}
