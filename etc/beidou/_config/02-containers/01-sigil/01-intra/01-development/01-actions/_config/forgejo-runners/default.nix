{lib, ...}: let
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
in {
  services.forgejo-runner = {
    instances = {
      achird = {
        enable = true;
        settings = {
          server = {
            connections = {
              default = {
                token_url = "file:${credentialsDirectory "forgejo-runner-achird"}/token";
                url = "https://forge.dev.intra.net.internal";
                uuid = "dae07cdb-1906-47c7-bb40-a0cc1642dd43";
              };
            };
          };
        };
      };
      adhara = {
        enable = true;
        settings = {
          server = {
            connections = {
              default = {
                token_url = "file:${credentialsDirectory "forgejo-runner-adhara"}/token";
                url = "https://forge.dev.intra.net.internal";
                uuid = "b62cfe7e-b2cd-4644-bc03-973f4267768b";
              };
            };
          };
        };
      };
      alioth = {
        enable = true;
        settings = {
          server = {
            connections = {
              default = {
                token_url = "file:${credentialsDirectory "forgejo-runner-alioth"}/token";
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
