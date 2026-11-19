{
  config,
  self,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.extra.files.list) recursive;
  inherit (lib.extra.sigil) getConfig getULA shortPathToContainers;
  inherit (lib.modules) mkAfter mkMerge;
  inherit (lib.meta) getExe';
in let
  targetConfig = getConfig target;

  containers = shortPathToContainers config;

  target = containers.porti.${mid};

  mid = "ea3680ca-4e51-4e86-b467-7f85d573834e";
in let
  state = let
    container = "/state/var/lib/machines/${mid}";
  in {
    inherit container;

    services = {
      forgejo = "${container}/var/lib/forgejo";
    };
  };

  backup = let
    name = mid;
  in {
    repository = {
      sftp = {
        host = "u542221-sub3.your-storagebox.de";
        port = 23;
        user = "u542221-sub3";
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
          snapshot = let
            name = "backup-${mid}";
            root = "/state/.zfs/snapshot/${name}";
          in let
            state = let
              container = "${root}/var/lib/machines/${mid}";
            in {
              inherit container;

              services = {
                forgejo = "${container}/var/lib/forgejo";
              };
            };
          in {
            dataset = "pool/state";

            inherit name state;
          };
        in
          mkMerge [
            (let
              zfs = getExe' config.boot.zfs.package "zfs";
            in {
              # Preparation
              # -----------
              backupPrepareCommand = ''
                ${zfs} destroy ${snapshot.dataset}@${snapshot.name} 2>/dev/null || true

                systemctl --machine=${mid} stop forgejo.service
                trap 'systemctl --machine=${mid} start forgejo.service' EXIT
                ${zfs} snapshot ${snapshot.dataset}@${snapshot.name}
              '';

              backupCleanupCommand = ''
                ${zfs} destroy ${snapshot.dataset}@${snapshot.name}
              '';
            })
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
              paths = [snapshot.state.services.forgejo];

              exclude = [
                "${snapshot.state.services.forgejo}/data/indexers"
                "${snapshot.state.services.forgejo}/data/repo-archive"
                "${snapshot.state.services.forgejo}/data/tmp"
                "${snapshot.state.services.forgejo}/log"
              ];

              timerConfig = {
                OnCalendar = "hourly";
                RandomizedDelaySec = "5m";
                Persistent = true;
              };
            }
            {
              # Maintenance/Pruning
              # -------------------
              pruneOpts = [
                "--keep-hourly 48"
                "--keep-daily 14"
                "--keep-weekly 8"
                "--keep-monthly 24"
                "--keep-yearly 10"
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
                      "${state.services.forgejo}:/var/lib/forgejo:idmap"
                      "/state/var/lib/machines/${mid}/etc/ssh/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key:idmap"
                      "/state/var/lib/machines/${mid}/etc/ssh/ssh_host_ed25519_key.pub:/etc/ssh/ssh_host_ed25519_key.pub:idmap"
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
                          ports =
                            [
                              targetConfig.services.forgejo.settings.server.HTTP_PORT
                            ]
                            ++ targetConfig.services.openssh.ports;
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
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host+tpm2 --name=password - -
          "password" = ''
            FBQliBiiQM2QC86GLbXHuSAAAAABAAAADAAAABAAAADqc31iAcBLlAVqJP0AAAAAAAAAAAAAAAALAAE
            A8AAAACAAAAAAngAgLxOefFtDlQBLZhkxAZ8HZN2fPF+3U5ZdQcd+dqqqtEcAEPHUfwSWidclKZhyUw
            +gGkxft4YGtIxMWvl4vB3+TN6XuXYUfkwMn1WtxOXY1YJ40X3ZIIWf8P83560TiSkQrb9cU43PWM6DS
            7Q3GS1mxmlnxf3eS/s1BAv9LFc3rndTf+It40//cpHYXXhTLycUHRwuEKMcv1SlNtv2AE4ACAALAAAE
            EgAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAgeV2KpKkikw+6R1h/ZrtY3Kppfji
            JzDmjnnMVegx9jecAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIAQAAgQAAAQAiAA
            vuAJGu9FG/Eb+WYnnVLQXm3zjWOfik0jijrtS8Ce3x5QAAAAEBGgABAAsAAwRyAAAABgCAAEMAEAgAA
            AAAAAEA1Q9Nxt85tUmGkPRycTFNNg4hKxomyu6kSN5zdOjY7ayDd6VguqHOJlGF4ehVVB7rmLqjWK5H
            zBU5rG+Y7/V9nJ+7GH2WyQ9Jsz5XNw0wRW4Q5vqUPw5Lp5Sw2zXfKjHQNe7DpkGc9CPMJmSUAlKuCWs
            HJPbGKI+gAYMxLO3Lkx/0J2Bej8AT1Ig4pZTtlIUw7IG4sF7WyoUQjI4GHoeepVkOuz+NBHEyRFd5B0
            +1s+JqDguP/+1hbE8lDXglH1xGZQtzmmjZTO/CzyyTw4It8JbnO11EkRXT69+xE2gB1WfWhP3EGWmVO
            4ue3atJ+wGSP+CnysQh6gpLM9qT0tOAHQAAAAB5M3voSO6YJuy9vpZNzgfroc6iVE8nSsKGJs03bY+n
            aGsWy7WBvgRMM+Al01DZ18QP3mqxSpfGXNPqWLo1dM+MhZ6wz0Y4UDAEQKkQ5H4jXESZGtL29Xc+5vN
            ChW97kC1VdwI4vHs1WLsN2JilYG07
          '';
          # cat /tmp/u542221-sub3@u542221-sub3.your-storagebox.de | systemd-creds encrypt --with-key=host+tpm2 --name=u542221-sub3@u542221-sub3.your-storagebox.de - -
          "u542221-sub3@u542221-sub3.your-storagebox.de" = ''
            FBQliBiiQM2QC86GLbXHuSAAAAABAAAADAAAABAAAACfR/lZILhaZkJurhQAAAAAAAAAAAAAAAALAAE
            A8AAAACAAAAAAngAg2C7iwGPNhlRKD7x664+JZEEs9qzKqNHEYbce9PN6rYgAEEO4Qof7frY3VEwgDj
            mDKjKUVRfcJHCe4xop9FqlvvH0jbh6e9D4KvVTcfA57Q4bVRPj4gdV479AMIjZa2JepNJ0tST72YbKy
            oRFp8mGI2Ne9JCfij0v5Xny5L4enBKV/fpep42xCOBjKbcRP43bMEO/zJuBoWP6I2R5AE4ACAALAAAE
            EgAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAgSwuUwwOO3FbIlO3N1xwaUD1T0u0
            T0llbHEE9vV97VG0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIAQAAgQAAAQAiAA
            vuAJGu9FG/Eb+WYnnVLQXm3zjWOfik0jijrtS8Ce3x5QAAAAEBGgABAAsAAwRyAAAABgCAAEMAEAgAA
            AAAAAEA1Q9Nxt85tUmGkPRycTFNNg4hKxomyu6kSN5zdOjY7ayDd6VguqHOJlGF4ehVVB7rmLqjWK5H
            zBU5rG+Y7/V9nJ+7GH2WyQ9Jsz5XNw0wRW4Q5vqUPw5Lp5Sw2zXfKjHQNe7DpkGc9CPMJmSUAlKuCWs
            HJPbGKI+gAYMxLO3Lkx/0J2Bej8AT1Ig4pZTtlIUw7IG4sF7WyoUQjI4GHoeepVkOuz+NBHEyRFd5B0
            +1s+JqDguP/+1hbE8lDXglH1xGZQtzmmjZTO/CzyyTw4It8JbnO11EkRXT69+xE2gB1WfWhP3EGWmVO
            4ue3atJ+wGSP+CnysQh6gpLM9qT0tOAHQAAAADLMMS915zFe2iwAWINsTY8n4tQbyX6+/wehbF26FBy
            3WjvrNO34NaQW0M+Y2JvNeHRWG0J15HX9RSe4/7hQEAaFS2aSNslUZCDVup9xWk1NqBTfY/+x9sW3rq
            awYzKVwBshfzDVDXBmBVtjed6ODsFi3PxRjWqtB+OxmEuOYpVPnLhPlVQAX4flvm0v/1WUkGdcygzBU
            xQ6gmTrPiKB2UouYXO3msNIlPwfw1IqTdaXJGz6R+cVIg+8TkdhpbovJBufTKSRQI95e/Ft4y+HabH4
            ke3InN6cv3S1yWfhHYO4Q/fmPDIarlId5Uyk1w8T6HadKSdf1JOe/a4AcV+O/To4oeHbMdXlwNpPTbc
            S3CyVtYBul6NZI5ykR7pIGJw1hpH3wA+IUegiJR4ZM6REJYpbDbdoCKxPZX1ZFkfFuC0AWaAASq672u
            V8rMpcP4uvTWDGRAs1BII6dpzQfVjLtxiZj7HZoI6DGA2GwxyTs3o/k7MoR8r2N7+pe8KwhTnMkNtxN
            c5Ekwh8JNSigTW5MWZDu4LYUWCMF4LxaT/lGgwywD7AKNctd2a2sRADQAsXaitc15efo8lO9QsUgd5+
            P2nYcJcRohnwiA8gstGqKWS6DTkqjaAlTOTHly7nk1QWA==
          '';
        };
      };
    };
    "systemd-nspawn@${mid}" = {
      serviceConfig = {
        LoadCredentialEncrypted = [
          # { xxd -r -p <<< "$(systemd-id128 show "ea3680ca4e514e86b4677f85d573834e" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
          "credential.secret:${./_secret/credential.secret.encrypted}"
        ];
      };
    };
  };
}
