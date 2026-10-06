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
      # cat /tmp/intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=intra.net.internal-key.pem - -
      "intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAGBlPIxd1u6NawYfEAAAAAohZpS7LS+pwpv6p
        6EQqiISQUChWEVOpqMU88q5x/drOWt+JAJnXVcZc+bqm9LO79eDR8y3gKeaTeUG4qtWlmOw5EJPSGHb
        fw3CTN+D/HPFfDKXehE8tgmdFMNGDxqhZWTqZSrrhBMcYxcW6T+zkLeCTPv36vawfYSYyofKnOVvGia
        SH/HVhPH65/UOQUoEH+fOYIzJU6qZPEuXER+I4iHA/bYPDr/aCjDSdTzQHehkPXukc5Aq0Qj6OebAW/
        BUIiAn02cxIeuQYxgfjvH5zvQgeNmr/AYDea54deF/0w64/Ov4L70A0VpxDEM0Bi21tEJpLwyyv5tai
        WJqYAzH9Z0WrPZ8LcU8Hr1BsOOH8mfCcYpFPBdTQpYK/0g427Cz0UlFX5
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
