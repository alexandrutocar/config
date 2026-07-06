{pkgs, ...}: let
  serverName = "ueuie.earth";
in {
  services.caddy.virtualHosts = {
    "ueuie.earth" = let
      root.path = pkgs.writeTextDir "index.html" ''
        Hello, ueuie.earth!
      '';
    in {
      listenAddresses = ["::"];

      logFormat = ''
        output file /var/log/caddy/${serverName}.access.log
        format json
      '';

      extraConfig = ''
        tls {
          issuer acme {
            email hostmaster@${serverName}
            disable_http_challenge
          }
        }

        root * ${root.path}
        header Content-Type application/x-apple-aspen-config
        file_server
      '';
    };
  };
}
