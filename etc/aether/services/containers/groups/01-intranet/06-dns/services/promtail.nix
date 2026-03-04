{container, ...}: let
  inherit (container) self intranet-monitoring;
in {
  # PROMTAIL
  # --------
  services.promtail = {
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
          url = "http://${intranet-monitoring.localAddress}:3100/loki/api/v1/push";
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
}
