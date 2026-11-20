{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.alias) radii;
  inherit (lib.extra) ip url;
  inherit (lib.strings) concatStringsSep;
in let
  mirrors = {
    # Remotes allowed for migrations and pull/push mirrors.
    http = ["github.com" "*.github.com" "codeberg.org" "gitlab.com" "code.forgejo.org"];

    # SSH push-mirror remotes, tunnelled through tinyproxy via HTTP CONNECT.
    ssh = ["github.com" "ssh.github.com" "codeberg.org" "gitlab.com"];
  };

  proxy = let
    interface = url.mkInterface address port;

    address = radii.site.fischl.hostAddress |> ip.toCompressed;

    port = 8888;
  in {
    inherit interface address port;

    url = url.interface.toOrigin "http" interface |> url.origin.toString;
  };
in {
  services = {
    forgejo = {
      settings = {
        proxy = {
          PROXY_ENABLED = true;
          PROXY_HOSTS = "**";
          PROXY_URL = proxy.url;
        };

        "git.config"."http.proxy" = proxy.url;

        "git.timeout" = {
          DEFAULT = 3600;
          MIGRATE = 7200;
          CLONE = 7200;
          PULL = 3600;
        };

        migrations = {
          # Allow-listed domains skip the local-network check, so they work
          # through the ULA proxy while everything else stays blocked.
          ALLOWED_DOMAINS = concatStringsSep "," mirrors.http;

          # Migrating large repositories may fail on first attempt.
          MAX_ATTEMPTS = 3;
        };

        # Queries a DNS TXT record, which would bypass the proxy.
        "cron.update_checker" = {
          ENABLED = false;
        };
      };
    };
  };

  systemd = {
    services = {
      forgejo = {
        # Catch-all for HTTP clients (Go default transport, git, curl) that
        # do not use Forgejo's [proxy] settings.
        environment = let
          exclude = concatStringsSep "," [
            "localhost"
            "127.0.0.1"
            "::1"
            config.services.forgejo.settings.server.HTTP_ADDR
            "guard.ueuie.earth"
          ];
        in {
          HTTP_PROXY = proxy.url;
          http_proxy = proxy.url;

          HTTPS_PROXY = proxy.url;
          https_proxy = proxy.url;

          NO_PROXY = exclude;
          no_proxy = exclude;
        };

        serviceConfig = {
          IPAddressDeny = "any";
          IPAddressAllow = [
            proxy.address
          ];
        };
      };
    };
  };

  programs = {
    ssh = {
      extraConfig = ''
        Host ${concatStringsSep " " mirrors.ssh}
          ProxyCommand ${pkgs.netcat-openbsd}/bin/nc -X connect -x ${proxy.interface} %h %p
      '';
    };
  };
}
