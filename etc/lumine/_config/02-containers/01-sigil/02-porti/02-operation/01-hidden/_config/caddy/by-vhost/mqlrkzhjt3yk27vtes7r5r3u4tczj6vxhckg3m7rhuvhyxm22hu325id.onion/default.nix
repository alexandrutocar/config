{pkgs, ...}: let
  serverName = "mqlrkzhjt3yk27vtes7r5r3u4tczj6vxhckg3m7rhuvhyxm22hu325id.onion";
in {
  services.caddy = {
    inherit (pkgs.notes.caddy) extraConfig;

    virtualHosts = {
      "http://${serverName}" = {
        listenAddresses = [
          "::1"
        ];

        # ────────────────────────────────────────────────────────────────────────
        # NOTE: No logging!
        # ────────────────────────────────────────────────────────────────────────
        logFormat = "output discard";

        extraConfig = ''
          import ${pkgs.notes.caddy.importBlock}

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
