# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ ▄▀█ █▀▀ ▄▀█ █▄░█ ▄▀█
# █▄█ █▀▄ █▀█ █▀░ █▀█ █░▀█ █▀█
#
# grafana, data-sources, dashboards...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: {
  services.grafana = {
    enable = true;

    # SETTINGS
    # --------
    settings = {
      analytics = {
        reporting_enabled = false;
      };

      server = let
        inherit (container.self) localAddress;
      in {
        # http
        http_addr = localAddress;
        http_port = 8080;

        # etc.
        enable_gzip = true;
        enforce_domain = false;
      };

      security = {
        # ────────────────────────────────────────────────────────────────────────
        # TODO(SECURITY): Change and hide the secret from version control.
        # ────────────────────────────────────────────────────────────────────────
        secret_key = "SW2YcwTIb9zpOOhoPsMm";
      };
    };
  };
}
