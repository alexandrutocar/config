{
  sigil,
  self,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
  inherit (lib.modules) mkMerge;
in let
  colleiContainers = shortPathToContainers self.nixosConfigurations.collei.config;
in {
  systemd = {
    services = {
      pocket-id = {
        serviceConfig = {
          SetCredentialEncrypted = mkSetCredentialEncrypted {
            # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host --name=encryption_key - -
            "encryption_key" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAABaanVrk3aY5LDHii8AAAAAe+Cb6TIUw/YYVbV
              HdsC+QwEeFH/c4adkAkuAN7p5ih5hbvHBMenchxgYHx2fCjKb3BAdHFSmzz0jwqVMJ2DFo3c5XrguM8
              RcxbAh9mOq05HFXdPQpkEhBf2j8Arr6sHIQZ3N5tg093rKP3DOQFwl2YSb7dTjnLFO
            '';
          };
        };
      };
    };
  };

  services.pocket-id = {
    enable = true;

    settings = mkMerge [
      # Telemetry
      {
        VERSION_CHECK_DISABLED = true;
        ANALYTICS_DISABLED = true;
      }
      # Security
      {
        ALLOW_INSECURE_CALLBACK_URLS = false;
      }
      # Server
      {
        HOST = sigil.self |> getULA |> ip.toCompressed;
        PORT = 8080;
        TRUST_PROXY = colleiContainers.porti.c8ac5cd5-7563-4e68-9dce-68bb11224eab |> getULA |> ip.toCIDR;
      }
      # Service
      {
        ENCRYPTION_KEY_FILE = "${credentialsDirectory "pocket-id"}/encryption_key";

        APP_URL = "https://guard.ueuie.earth";

        APP_NAME = "Guard";

        HOME_PAGE_URL = "/settings/apps";

        UI_CONFIG_DISABLED = true;
      }
    ];
  };
}
