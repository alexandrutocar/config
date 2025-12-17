# ────────────────────────────────────────────────────────────────────────
#
# █░█ █▄░█ █▄▄ █▀█ █░█ █▄░█ █▀▄
# █▄█ █░▀█ █▄█ █▄█ █▄█ █░▀█ █▄▀
#
# unbound, dns, resolver...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;

  inherit (container) self x0-ins;
in {
  services = {
    # UNBOUND
    # -------
    unbound = {
      enable = true;

      package =
        (
          pkgs.unbound.override {
            withSystemd = true;
            withDNSTAP = true;
            withECS = true;
            withDoH = true;
            withTFO = true;
            withRedis = true;
          }
        ).overrideAttrs (oldAttrs: let
          version = "1.24.2";
        in {
          src = pkgs.fetchFromGitHub {
            owner = "NLnetLabs";
            repo = "unbound";
            tag = "release-${version}";
            hash = "sha256-kyTcDmNGKJuOMZ7cxIWh6o7aasRUoAB4M0tIG81BQsE=";
          };
        });

      settings = {
        server = mkMerge [
          {
            interface = map (port: "${self.address}@${toString port}") [53 853];

            quic-port = 853;
            tls-port = 853;

            do-udp = true;
            do-tcp = true;

            tls-service-key = "/var/lib/acme/aether.ip/key.pem";
            tls-service-pem = "/var/lib/acme/aether.ip/fullchain.pem";
          }
          {
            # https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html#unbound-conf-access-control
            access-control = map (address: "${address} allow") [
              # Local Area Network
              "192.168.0.0/24"

              # Containers
              "10.0.0.0/24"

              # Virtual Private Network
              "10.200.200.0/24"
            ];
          }
          {
            deny-any = true;
          }
          {
            aggressive-nsec = true;
            use-caps-for-id = true;

            hide-identity = true;
            hide-version = false;

            harden-algo-downgrade = true;
            harden-below-nxdomain = true;

            harden-large-queries = true;
            harden-referral-path = true;

            harden-dnssec-stripped = true;
            harden-unverified-glue = true;
          }
          {
            cache-min-ttl = 0;
            serve-expired-reply-ttl = 0;
          }
          {
            # https://nlnetlabs.nl/documentation/unbound/howto-optimise/
            num-threads = 8;

            key-cache-slabs = 8;
            infra-cache-slabs = 8;
            msg-cache-slabs = 8;
            rrset-cache-slabs = 8;

            # Due to `malloc` overhead, the total memory usage
            # is likely to rise to double (or 2.5x) the total
            # cache memory that is entered into the config.
            rrset-cache-size = "128m";
            msg-cache-size = "64m";

            outgoing-range = 64;
            num-queries-per-thread = 32;
          }
          {
            log-queries = true;
            log-replies = true;
          }
          {
            extended-statistics = true;
          }
        ];

        auth-zone = [
          {
            name = "aether.ip";
            zonefile = "/var/lib/unbound/zones/aether.ip.zone";
          }
        ];

        # Control socket is used
        # by a metrics exporter.
        remote-control = {
          control-enable = true;
          control-interface = "/var/run/unbound/unbound.sock";
        };
      };
    };

    # PROMETHEUS
    # ----------
    prometheus.exporters.unbound = {
      enable = true;
      port = 9090;
      listenAddress = self.address;

      unbound.host = "unix:///var/run/unbound/unbound.sock";
    };

    # LOGROTATE
    # ---------
    logrotate.settings = {
      "/var/log/unbound/unbound.log" = {
        daily = true;
        rotate = 7;
        missingok = true;
        compress = true;
        delaycompress = true;
        notifempty = true;
        postrotate = ''
          unbound-control log_reopen
        '';
        endscript = true;
      };
    };

    # PROMTAIL
    # --------
    promtail = {
      enable = true;

      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
          log_level = "warn";
        };

        positions.filename = "/tmp/positions.yaml";

        clients = [
          {
            url = "http://${x0-ins.address}:3100/loki/api/v1/push";
          }
        ];

        scrape_configs = [
          {
            job_name = "unbound";
            static_configs = [
              {
                targets = [
                  "localhost"
                ];

                labels = {
                  job = "unbound";
                  __path__ = "/var/log/unbound/unbound.log";
                };
              }
            ];

            pipeline_stages = [
              {
                labeldrop = [
                  "filename"
                ];
              }
              {
                match = {
                  selector = ''{job="unbound"} |~ " start | stopped |.*in-addr.arpa."'';
                  action = "drop";
                };
              }
              {
                match = {
                  selector = ''{job="unbound"} |= "reply:"'';
                  stages = [
                    {
                      static_labels.dns = "reply";
                    }
                  ];
                };
              }
              {
                match = {
                  selector = ''{job="unbound"} |~ "always_null|redirect |always_nxdomain"'';
                  stages = [
                    {
                      static_labels.dns = "block";
                    }
                  ];
                };
              }
            ];
          }
        ];
      };
    };
  };
}
