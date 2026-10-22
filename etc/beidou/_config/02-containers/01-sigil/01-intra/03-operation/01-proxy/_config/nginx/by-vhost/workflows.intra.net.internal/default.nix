{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6;
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
in let
  extraConfig = ''
    access_log /var/log/nginx/workflows.intra.net.internal.access.log analytics;
    error_log /var/log/nginx/workflows.intra.net.internal.error.log;
  '';

  kTLS = true;

  onlySSL = true;

  serverName = "workflows.intra.net.internal";

  sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal/workflows.intra.net.internal.pem";

  sslCertificateKey = "${credentialsDirectory "nginx"}/workflows.intra.net.internal-key.pem";
in {
  systemd.services.nginx.serviceConfig = {
    SetCredentialEncrypted = mkSetCredentialEncrypted {
      # cat /tmp/workflows.intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=workflows.intra.net.internal-key.pem - -
      "workflows.intra.net.internal-key.pem" = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADB0mDoypikRLiwUF4AAAAAytWCyxTNP7SkAOW
        9VhTpRSxlARvHoSb5drTLvOjX05H2wdyM5EZNOezWRCArSI9NLAXDb0URsG8xRgUIZUdP4s/UGgN6RL
        dbDGD1EJJv4RJ+gVsqQ80m2EquOafZ/H8qLByDc4dNVv/W818zjjWWXgqLROH3C1t/9HJW7y8creobE
        p44FF53pScblm9+FhRv4VYbIn9DDxhodxLXPSuddMaom2fltjGUtHeOvHVhfooDqm49qLrF2V5VM9kx
        3F9ZXMJgdALpkzcj/BV0GoMrLPPulOpdtvvrU7qC/8bP2Kyr9yuMWgSn2/Xs6uDQItxCV1d7XFa6nd5
        kJeSTmE9c44SnrUpGpijfJfE133CInlX32V6R6H7+bz3GVkgJrrfZL9iEGZ2NityaihM=
      '';
    };
  };

  services.nginx.virtualHosts = {
    "workflows.intra.net.internal" = {
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
          proxyWebsockets = true;
          proxyPass = "http://${ipv6.enclose sigil.containers.intra."a4205b50-197a-40c8-8057-fe1394630e91".addresses.ula}:8080";
        };
      };
    };
  };
}
