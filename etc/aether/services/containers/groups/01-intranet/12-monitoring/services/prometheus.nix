# ────────────────────────────────────────────────────────────────────────
#
# █▀█ █▀█ █▀█ █▀▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █░█ █▀
# █▀▀ █▀▄ █▄█ █░▀░█ ██▄ ░█░ █▀█ ██▄ █▄█ ▄█
#
# prometheus, scrapers, exporters...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (container) intranet-dns intranet-gateway intranet-harmonia internet-gateway;
in {
  services.prometheus = {
    enable = true;

    port = 9090;
    stateDir = "prometheus";
    listenAddress = "0.0.0.0";

    globalConfig.scrape_interval = "10s";
    scrapeConfigs = [
      (let
        inherit (config.services.prometheus.exporters.node) listenAddress port;
      in {
        job_name = "node";
        static_configs = [
          {
            targets = ["${listenAddress}:${toString port}"];
          }
        ];
      })
      {
        job_name = "foxess";
        scheme = "http";
        scrape_interval = "5m";
        fallback_scrape_protocol = "PrometheusText0.0.4";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString 9092}"];
          }
        ];
      }
      {
        job_name = "nginx";
        scheme = "http";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = ["${internet-gateway.localAddress}:9090" "${intranet-gateway.localAddress}:9090"];
          }
        ];
      }
      {
        job_name = "unbound";
        scheme = "http";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = ["${intranet-dns.localAddress}:9090"];
          }
        ];
      }
      {
        job_name = "harmonia";
        scheme = "http";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = ["${intranet-harmonia.localAddress}:8080"];
          }
        ];
      }
    ];
  };

  services.prometheus.exporters.node = {
    enable = true;
    port = 9091;
    listenAddress = "127.0.0.1";

    # For the list of available collectors, run, depending on your install:
    # - Flake-based: nix run nixpkgs#prometheus-node-exporter -- --help
    # - Classic: nix-shell -p prometheus-node-exporter --run "node_exporter --help"
    enabledCollectors = [
      "cpu_vulnerabilities"
      "ethtool"
      "logind"
      "mountstats"
      "network_route"
      "slabinfo"
      "sysctl"
      "systemd"
      "swap"
      "wifi"
    ];

    # You can pass extra options to the exporter using `extraFlags`, e.g.
    # to configure collectors or disable those enabled by default.
    # Enabling a collector is also possible using "--collector.[name]",
    # but is otherwise equivalent to using `enabledCollectors` above.
    extraFlags = ["--collector.ntp.protocol-version=4" "--path.procfs=/host/proc" "--path.sysfs=/host/sys" "--path.rootfs=/host/root"];
  };

  systemd.services.prometheus-foxess-exporter = let
    inherit (lib.extra.systemd) mkSetCredentialEncrypted;
    inherit (lib.meta) getExe;
  in {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      SetCredentialEncrypted = mkSetCredentialEncrypted {
        cloud-api-key = ''
          Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAmfLp5bbL/GOmaZEMAAAAAqeAvL
          WN/JnC2LLEPFLMN7xzbFt+W4SV3IodWPtWgvriM52A2V+uw3pDfxmZ4GlIzJrqVtC393R
          P22ArHQmOKGgOPly8fXrssv0r6ALk746lAm0qoRXDPczTkprg=
        '';
      };
      ExecStart = getExe (
        pkgs.custom.writeShell "prometheus-foxess-exporter.bash" {
          inputs = with pkgs.custom; [foxessprom];
          text = ''
            foxessprom --bind 127.0.0.1:9092 --cloud-api-key "$CLOUD_API_KEY" --cloud-update-freq 300
          '';
          env = {
            CLOUD_API_KEY.cred = "cloud-api-key";
          };
        }
      );
      DynamicUser = true;
      Restart = "always";
    };
  };
}
