# ────────────────────────────────────────────────────────────────────────
#
# █▀█ █▀█ █▀ ▀█▀ █▀▀ █▀█ █▀▀ █▀ █▀█ █░░
# █▀▀ █▄█ ▄█ ░█░ █▄█ █▀▄ ██▄ ▄█ ▀▀█ █▄▄
#
# postgresql, databases, authentication...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;

  inherit (container) self intranet-dav;
in {
  services.postgresql = {
    enable = true;
    settings = {
      port = 5432;
      listen_addresses = mkForce self.localAddress;
    };

    authentication = ''
      host  davis davis ${intranet-dav.localAddress}/32 trust
    '';

    ensureUsers = [
      {
        name = "davis";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "davis"
    ];
  };

  # systemd.services."postgresql-fix-collation" = {
  #   description = "Fix PostgreSQL collation version mismatch";
  #   requires = ["postgresql.service"];
  #   after = ["postgresql.service"];
  #   wantedBy = ["postgresql.service"];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     User = config.services.postgresql.superUser;
  #     RemainAfterExit = true;
  #     ExecStart = getExe (
  #       pkgs.custom.writeShell "postgresql-fix-collation.bash" {
  #         inputs = singleton config.services.postgresql.package;
  #         text = ''
  #           # Fix template1 (connect to postgres db to do this)
  #           psql -d postgres -c "ALTER DATABASE template1 REFRESH COLLATION VERSION;" || true

  #           # Fix postgres database (connect to template1 to do this)
  #           psql -d template1 -c "ALTER DATABASE postgres REFRESH COLLATION VERSION;" || true

  #           # Fix existing databases if they exist
  #           psql -d postgres -c "ALTER DATABASE miniflux REFRESH COLLATION VERSION;" 2>/dev/null || true
  #           psql -d postgres -c "ALTER DATABASE davis REFRESH COLLATION VERSION;" 2>/dev/null || true
  #         '';
  #       }
  #     );
  #   };
  # };
}
