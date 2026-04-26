{config, ...}: {
  services.grafana.provision = {
    # DASHBOARDS
    # ----------
    dashboards.settings = {
      providers = [
        {
          name = "Dashboards";
          disableDeletion = true;
          options = {
            path = "/etc/grafana-dashboards";
            foldersFromFilesStructure = true;
          };
        }
      ];
    };

    # DATASOURCES
    # -----------
    datasources.settings = {
      datasources = [
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          orgId = 1;
          editable = false;
        }
      ];
    };
  };
}
