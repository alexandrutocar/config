# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █░░ █░░ █▀█ █▄█
# █▀█ █▄▄ █▄▄ █▄█ ░█░
# 
# tags: alloy, monitoring
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: {
  services.alloy = {
    enable = true;
    extraFlags = [
      # ────────────────────────────────────────────────────────────────────────
      # NOTE(SECURITY): Service must be accessible from both inside and outside
      #                 the container, hence the broad '0.0.0.0' listen address.
      # ────────────────────────────────────────────────────────────────────────
      "--server.http.listen-addr=0.0.0.0:9090"
    ];
  };

  # SETTINGS
  # --------
  environment.etc."alloy/config.alloy".text = let
    inherit (container) intranet-dns internet-gateway intranet-harmonia;
  in /* alloy */ ''
    // EXPORTERS
    // ---------

    prometheus.exporter.unix "node" {
      enable_collectors = [
        "cpu_vulnerabilities", "ethtool", "logind",
        "mountstats", "network_route", "slabinfo",
        "sysctl", "systemd", "swap", "wifi",
      ]

      procfs_path  = "/host/proc"
      sysfs_path   = "/host/sys"
      rootfs_path  = "/host/root"
    }

    // SCRAPERS
    // --------

    prometheus.scrape "node" {
      targets       = prometheus.exporter.unix.node.targets
      forward_to    = [prometheus.remote_write.mimir.receiver]
    }


    prometheus.scrape "nginx" {
      targets       = [{ __address__ = "${internet-gateway.localAddress}:9090" }]
      metrics_path  = "/metrics"
      forward_to    = [prometheus.remote_write.mimir.receiver]
    }

    prometheus.scrape "unbound" {
      targets       = [{ __address__ = "${intranet-dns.localAddress}:9090" }]
      metrics_path  = "/metrics"
      forward_to    = [prometheus.remote_write.mimir.receiver]
    }

    prometheus.scrape "harmonia" {
      targets       = [{ __address__ = "${intranet-harmonia.localAddress}:8080" }]
      metrics_path  = "/metrics"
      forward_to    = [prometheus.remote_write.mimir.receiver]
    }

    // STORAGE
    // -------
    
    prometheus.remote_write "mimir" {
      endpoint {
        url = "http://127.0.0.1:8080/api/v1/push"
      }
    }
  '';
}
