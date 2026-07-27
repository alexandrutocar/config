{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6;
  inherit (lib.extra.cs.systemd) mkSetCredentialEncrypted;
in let
  extraConfig = ''
    access_log /var/log/nginx/intra.net.internal.access.log analytics;
    error_log /var/log/nginx/intra.net.internal.error.log;
  '';

  kTLS = true;

  onlySSL = true;

  serverName = "intra.net.internal";

  sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal.pem";

  sslCertificateKey = "/run/credentials/nginx.service/intra.net.internal-key.pem";
in {
  systemd.services.nginx.serviceConfig = {
    SetCredentialEncrypted = mkSetCredentialEncrypted {
      "intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADVtgmcrVbpqzHU3+gAAAAANuwocUGZvTqOEhv
        ALpV1IeR/uZdRh+gQDEGTe3KAWYrv9QBaN0hf2Pa4iyxFBq3sQO9mS1i9qo3dJMzv/I1cTuu4cSxwLF
        BlSyDMLRYqy2tSb87xCJVa9cWkVBNL6p/buCagmLejcly9ngVRKwhmcIiirFacs6bFBetUv7+AXE780
        WFY96ad6M1rqVy/hGkGL3hIwTt0yqhFgE3qKKt0/2sV1ereCdl0oDdn9+z5rZDBjBZB4ERTeboDC9VI
        MWqiSNuZ+8EJOxh31OAvT1HWilqdQnFRmJUht/8BmFtqnexbWvTlJjc9GybVafIqkKkk62tWAAh5NL0
        Y0TsI57P8i02gC3zTWgreDn4L4vvhjrdcuPBabskJc5tjMp3eeDv32Q0U
      '';
    };
  };

  services.nginx.virtualHosts = {
    "_" = {
      inherit kTLS onlySSL sslCertificate sslCertificateKey;

      default = true;

      extraConfig = ''
        access_log /var/log/nginx/_.access.log analytics;
        error_log /var/log/nginx/_.error.log;
        ssl_reject_handshake on;
        return 444;
      '';

      listen = [
        {
          addr = ipv6.enclose sigil.self.addresses.ula;
          port = 443;
          ssl = true;
        }
      ];
    };

    "intra.net.internal" = {
      inherit extraConfig kTLS onlySSL serverName sslCertificate sslCertificateKey;

      listen = [
        {
          addr = ipv6.enclose sigil.self.addresses.ula;
          port = 443;
          ssl = true;
        }
      ];

      locations = {
        "/" = {
          proxyPass = "http://${ipv6.enclose sigil.containers.intra."a8e714de-f158-49fc-958a-9176f25d2973".addresses.ula}:8080";
        };
        "/.well-known/apple-device-configuration/intra.net.mobileconfig" = let
          inherit (lib.generators) mkPlistData;
          mobileConfig = pkgs.formats.plist {};
        in let
          toPayloadContent = path: let
            nativeBuildInputs = with pkgs; [coreutils];
          in let
            toBase64 = path:
              pkgs.runCommand "${baseNameOf path}.b64" {
                inherit nativeBuildInputs;
              } ''
                base64 -i ${path} > $out
              '';
          in
            builtins.readFile (
              pkgs.runCommand (baseNameOf path) {
                inherit nativeBuildInputs;
              } ''
                fold -w 52 ${(toBase64 path)} > $out
              ''
            );
        in let
          profile.path = mobileConfig.generate "intra.net.mobileconfig" {
            PayloadType = "Configuration";
            PayloadUUID = "c6b8db95-7310-4ca5-a940-0f11ca14083e";

            PayloadDisplayName = "intra.net®";
            PayloadDescription = "Anker-Zertifikat";

            PayloadIdentifier = "com.intra.net.profile";
            PayloadOrganization = "Internes Netz";
            PayloadRemovalAllowed = true;

            PayloadVersion = 2;
            PayloadContent = [
              {
                PayloadType = "com.apple.security.pem";
                PayloadUUID = "9f431220-ef98-4e0c-a275-fd8188ce40fa";

                PayloadDisplayName = "Anker-Zertifikat";
                PayloadDescription = "Konfiguriert den Anker-Zertifikat für Dienste im internen Netz.";

                PayloadIdentifier = "com.intra.net.ca.root";

                PayloadVersion = 1;

                # Payload Specific
                # ----------------
                PayloadContent = mkPlistData (toPayloadContent "${pkgs.certs}/etc/ssl/anchor/intra.net.pem");
              }
            ];
          };
        in {
          alias = profile.path;
          tryFiles = "$uri =404";
          extraConfig = ''
            default_type application/x-apple-aspen-config;
          '';
        };
      };
    };
  };
}
