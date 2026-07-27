{
  sigil,
  pkgs,
  ...
}: let
  certs =
    pkgs.runCommand "stalwart-webui-mirror.internal-certs"
    {
      nativeBuildInputs = with pkgs; [openssl];
      outputs = ["out"];
    }
    ''
      mkdir -p $out
      openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout key.pem -out cert.pem \
        -days 3650 \
        -subj "/CN=stalwart-webui-mirror.internal" \
        -addext "subjectAltName=IP:::1"

      cp key.pem cert.pem $out/
    '';
in {
  # CERTIFICATE
  # -----------
  security.pki.certificateFiles = [
    "${certs}/cert.pem"
  ];

  services.nginx = {
    enable = true;
    virtualHosts = {
      "stalwart-webui-mirror.internal" = let
        webui =
          pkgs.runCommand "stalwart-webui.zip"
          {
            nativeBuildInputs = with pkgs; [gnutar gzip zip];
            passthru.version = pkgs.stalwart_0_16.version;
          }
          ''
            tar -xzf ${pkgs.stalwart_0_16.webui}/webui.tar.gz
            ls -la 
            (cd dist && ls -la)

            # -X strips extra file attributes so the archive is reproducible
            # across platforms; -r recurses; output goes straight to $out.
            (cd "dist" && zip -r -X "$out" .)
          '';
      in {
        listen = [
          {
            addr = "[::1]";
            port = 443;
            ssl = true;
          }
        ];

        onlySSL = true;

        sslCertificate = "${certs}/cert.pem";
        sslCertificateKey = "${certs}/key.pem";

        locations = {
          "= /webui.zip" = {
            alias = webui;
            extraConfig = ''
              add_header Content-Type application/zip;
              add_header Cache-Control "no-cache";
            '';
          };
        };
      };
    };
  };
}
