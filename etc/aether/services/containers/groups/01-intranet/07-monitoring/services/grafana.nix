# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ ▄▀█ █▀▀ ▄▀█ █▄░█ ▄▀█
# █▄█ █▀▄ █▀█ █▀░ █▀█ █░▀█ █▀█
#
# grafana, data-sources, dashboards...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  config,
  pkgs,
  ...
}: let
  inherit (container) self;
in {
  environment.systemPackages = with pkgs; [
    sqlite
    sqlite-utils
  ];

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "${self.address}";
        http_port = 8080;
        enforce_domain = false;
        enable_gzip = true;
        domain = "metrics.ueuie.dev";
      };

      analytics.reporting_enabled = false;
    };

    provision = {
      dashboards.settings.providers = [
        {
          name = "Dashboards";
          disableDeletion = true;
          options = {
            path = "/etc/grafana-dashboards";
            foldersFromFilesStructure = true;
          };
        }
      ];

      datasources.settings.datasources = [
        # Provisioning a built-in data source
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          orgId = 1;
          isDefault = true;
          editable = false;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          orgId = 1;
          editable = false;
        }
        # Provisioning a built-in data source
        {
          name = "Prometheus";
          type = "prometheus";
          orgId = 2;
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
          editable = false;
        }
      ];
    };
  };
}
