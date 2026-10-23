{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.extra.net) ipv6;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        8443 # PROXY (TLS)
      ];
    };
  };

  systemd = {
    services = {
      nginx = {
        serviceConfig = {
          SetCredentialEncrypted = mkSetCredentialEncrypted {
            # cat /tmp/proxy.uni.intra.net.internal-key.pem | systemd-creds encrypt --with-key=host --name=proxy.uni.intra.net.internal-key.pem - -
            "proxy.uni.intra.net.internal-key.pem" = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAACz+k8o3zH8gNJXlqUAAAAA7873xXzKrTIL8fb
              sb0T/FFG08oeL8569ErhjVV4Nsv9QbCBHzdAKjJ3P0DeiRbNhC4OIoX39ki2XXUleO3f7Qp+qi9wsbh
              JqNHrXYu+OkwaAGnsWbpsdvlpR4+ydKnCGac9+PYUDtMUNkjT767P7FqkrD57BlWoyccr9688ZU84Wj
              5LAvKLyEhsWPjR+ctWEjUt3cf5EBiBv18z5cQ/0yc7OQbyN2r5/8NHrrYqW8CEr8f/cOWquC2V15Kyy
              9yiKkgqGmWuGcZertFqr0JDKbi5BLR7ZQjPOVAcLkOkYK+igcjMdaWcWaSua9RvREvDASsH76hPngUQ
              kXofwb47YnbXIkiMqVcep+hyUDfJhTAVaMN1ioHFN08qAyUsF8EKA4sEOWFeYfJJC7sw=
            '';
          };
        };
      };
    };
  };

  services = {
    nginx = let
      serverName = "proxy.uni.intra.net.internal";

      sslCertificate = "${pkgs.certs}/etc/ssl/server/intra.net.internal/proxy.uni.intra.net.internal.pem";

      sslCertificateKey = "${credentialsDirectory "nginx"}/proxy.uni.intra.net.internal-key.pem";
    in {
      streamConfig = ''
        upstream uni_proxy {
          server ${ipv6.enclose sigil.containers.intra."b6cab864-64cc-454d-8647-30348af279da".addresses.ula}:8888;
        }

        server {
          listen 8443 ssl default_server;

          listen ${ipv6.enclose sigil.self.addresses.ula}:8443 ssl default_server;

          allow ${sigil.containers.intra."a4205b50-197a-40c8-8057-fe1394630e91".addresses.ula}/128;
          allow fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a/128;
          deny all;

          ssl_certificate_key ${sslCertificateKey};
          ssl_certificate     ${sslCertificate};

          ssl_conf_command Options KTLS;

          return "";
        }

        server {
          listen 8443 ssl;
          listen ${ipv6.enclose sigil.self.addresses.ula}:8443 ssl;
          server_name ${serverName};

          ssl_certificate_key ${sslCertificateKey};
          ssl_certificate     ${sslCertificate};
          ssl_protocols TLSv1.2 TLSv1.3;

          ssl_conf_command Options KTLS;

          proxy_bind ${ipv6.enclose sigil.self.addresses.ula};
          proxy_pass uni_proxy;
        }
      '';

      virtualHosts = let
        extraConfig = ''
          access_log /var/log/nginx/proxy.uni.intra.net.internal.access.log analytics;
          error_log /var/log/nginx/proxy.uni.intra.net.internal.error.log;
        '';

        kTLS = true;

        onlySSL = true;
      in {
        ${serverName} = {
          inherit extraConfig kTLS onlySSL serverName sslCertificate sslCertificateKey;

          listen = [
            {
              addr = ipv6.enclose sigil.self.addresses.ula;
              port = 443;
              ssl = true;
            }
          ];

          locations = {
            "/proxy.pac" = let
              pac = pkgs.writeText "proxy.pac" ''
                function FindProxyForURL(url, host) {
                  if (dnsDomainIs(host, ".uni-bonn.de")) return "HTTPS ${serverName}:8443";
                  return "DIRECT";
                }
              '';
            in {
              alias = pac;
              tryFiles = "$uri =404";
              extraConfig = ''
                default_type application/x-ns-proxy-autoconfig;
              '';
            };
          };
        };
      };
    };
  };
}
