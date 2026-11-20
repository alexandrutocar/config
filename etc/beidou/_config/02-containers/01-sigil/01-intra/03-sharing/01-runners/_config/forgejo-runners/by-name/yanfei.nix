{lib, ...}: let
  inherit (lib.alias) radii;
  inherit (lib.extra) url;
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
in {
  services.forgejo-runner.instances = {
    yanfei = {
      enable = true;
      settings = {
        container = {
          options = "-v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro";
          valid_volumes = ["/etc/ssl/certs/ca-certificates.crt"];
        };

        runner = {
          labels = [
            "docker:docker://data.forgejo.org/oci/node:20-bookworm"
          ];
          envs = {
            HTTPS_PROXY = url.mkOrigin "http" radii.site.beidou.hostAddress 8888;
            NO_PROXY = ".ueuie.proxy,.intra.net.internal";
            NIX_CONFIG = "experimental-features = ca-derivations flakes nix-command parse-toml-timestamps pipe-operators";
          };
        };

        server = {
          connections = {
            default = {
              token_url = "file:${credentialsDirectory "forgejo-runner-yanfei"}/token";
              url = "https://forge.ueuie.earth";
              uuid = "6b68adb9-bf3f-4015-9ea7-b08fa2b56e60";
            };
          };
        };
      };
    };
  };

  systemd.services = {
    forgejo-runner-yanfei = {
      serviceConfig = {
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # echo -n '<token>' | systemd-creds encrypt --with-key=host --name=token - -
          token = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAt5Kh/E4RBtOUmK1gAAAAAfNw2pQora22eFJm
            9PVaUgGP+sOKPCAsTM5NFIDz8afJC53zkR/O1Cm9FQwSFPLFRXMbmqAaYGpBkBqmDYB21pNzDh+BTdY
            ISEk/Kw2LVF+qvqsFM8Q59Qw==
          '';
        };
      };
    };
  };
}
