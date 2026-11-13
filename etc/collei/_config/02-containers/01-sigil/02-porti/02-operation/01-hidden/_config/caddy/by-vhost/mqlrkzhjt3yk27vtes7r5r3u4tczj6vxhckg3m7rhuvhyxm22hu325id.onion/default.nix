{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.ip) toCompressed wellKnown;
  inherit (lib.extra.url) mkDefaultOrigin;
in let
  serverDomain = "mqlrkzhjt3yk27vtes7r5r3u4tczj6vxhckg3m7rhuvhyxm22hu325id.onion";
  serverOrigin = mkDefaultOrigin "http" serverDomain;
in let
  notesPackage = pkgs.notes serverOrigin;
in {
  services.caddy = {
    inherit (notesPackage.caddy) extraConfig;

    virtualHosts = {
      ${serverOrigin} = {
        listenAddresses = [
          (wellKnown.ipv6.loopback |> toCompressed)
        ];

        # ────────────────────────────────────────────────────────────────────────
        # NOTE: No logging!
        # ────────────────────────────────────────────────────────────────────────
        logFormat = "output discard";

        extraConfig = ''
          import ${notesPackage.caddy.importBlock}

          header {
            Permissions-Policy "accelerometer=(), camera=(), geolocation=(), microphone=()"
            Referrer-Policy "no-referrer"
            X-Frame-Options "DENY"
            X-Content-Type-Options "nosniff"
          }
        '';
      };
    };
  };
}
