# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █ █▄░█ ▀▄▀
# █░▀█ █▄█ █ █░▀█ █░█
#
# nginx
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  services.nginx = let
    package = pkgs.nginx.override {
      withGeoIP = true;
    };
  in {
    inherit package;

    enable = true;

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: Enabling status page allows collecting basic analytics.
    # ────────────────────────────────────────────────────────────────────────
    statusPage = true;

    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedBrotliSettings = true;
  };
}
