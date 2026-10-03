{lib, ...}: let
  inherit (lib.extra.cs.systemd) mkSetCredentialEncrypted;
in {
  services.forgejo-runner = {
    instances = {
      achird = let
        CREDENTIALS_DIRECTORY = "/run/credentials/forgejo-runner-achird.service";
      in {
        enable = true;
        settings = {
          server = {
            connections = {
              default = {
                token_url = "file:${CREDENTIALS_DIRECTORY}/token";
                url = "https://forge.dev.intra.net.internal";
                uuid = "dae07cdb-1906-47c7-bb40-a0cc1642dd43";
              };
            };
          };
        };
      };
      adhara = let
        CREDENTIALS_DIRECTORY = "/run/credentials/forgejo-runner-adhara.service";
      in {
        enable = true;
        settings = {
          server = {
            connections = {
              default = {
                token_url = "file:${CREDENTIALS_DIRECTORY}/token";
                url = "https://forge.dev.intra.net.internal";
                uuid = "b62cfe7e-b2cd-4644-bc03-973f4267768b";
              };
            };
          };
        };
      };
      alioth = let
        CREDENTIALS_DIRECTORY = "/run/credentials/forgejo-runner-alioth.service";
      in {
        enable = true;
        settings = {
          server = {
            connections = {
              default = {
                token_url = "file:${CREDENTIALS_DIRECTORY}/token";
                url = "https://forge.dev.intra.net.internal";
                uuid = "acc4ec70-0a64-44df-aec1-6b278695bea1";
              };
            };
          };
        };
      };
    };
  };

  systemd.services = {
    forgejo-runner-achird = {
      serviceConfig = {
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # echo -n '<token>' | systemd-creds encrypt --with-key=host --name=token - -
          token = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAC30K+A8ypZ8aUOCZQAAAAATO1mojs1nrheOeU
            Ym//c1fEisfo0bPqupJ9vP+fOn/fsdQN+VD6uyrYC/J4raiWJy2zavK9r53W18VPpNP+g/sQvV8sS56
            MqMbnrPYDJf5wS6nDUfvb8VA==
          '';
        };
      };
    };
    forgejo-runner-adhara = {
      serviceConfig = {
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # echo -n '<token>' | systemd-creds encrypt --with-key=host --name=token - -
          token = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAABwBReGLgjXWcUYmHYAAAAA7dayxjlFsEz1yKO
            5/pC2dOl6UCswe8gwfR47QRzMt/N4ChPcHtSO2VVpvShHfMWdeOeEbfNlFy+EVfkVY19P4LUh5ZPwSr
            jyw6pfd2HyZ7rU9diZx6GdSw==
          '';
        };
      };
    };
    forgejo-runner-alioth = {
      serviceConfig = {
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # echo -n '<token>' | systemd-creds encrypt --with-key=host --name=token - -
          token = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAApzBuGclzDXOODotIAAAAAYTJ3YYc2QINgl2v
            fP3eqnfVbEY9DnxP2LDKQdu5WvbljJXRAUG0JjK1rxjlsbjcDjcIxoxIrLx0AuKvtL0ot5XRy2zdSUq
            avYsnVBzAkIclInwEiCbEOYw==
          '';
        };
      };
    };
  };
}
