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
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkForce;

  inherit (container) self intranet-feed intranet-dav intranet-coder;
in {
  services.postgresql = {
    enable = true;
    settings = {
      port = 5432;
      listen_addresses = mkForce self.localAddress;
    };

    authentication = ''
      host  miniflux miniflux ${intranet-feed.localAddress}/32 trust
      host  davis davis ${intranet-dav.localAddress}/32 trust
      host  coder coder ${intranet-coder.localAddress}/32 trust
    '';

    ensureUsers = [
      {
        name = "miniflux";
        ensureDBOwnership = true;
      }
      {
        name = "davis";
        ensureDBOwnership = true;
      }
      {
        name = "coder";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "miniflux"
      "davis"
      "coder"
    ];
  };

  # DATABASE SET-UP
  # ---------------
  systemd.services = {
    "database-setup@miniflux" = {
      description = "Database Setup for 'miniflux'";
      requires = ["postgresql.target"];
      after = [
        "network.target"
        "postgresql.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        User = config.services.postgresql.superUser;
        ExecStart = getExe (
          pkgs.custom.writeShell "database-setup@miniflux.bash" {
            inputs = singleton config.services.postgresql.package;
            text = ''
              psql "miniflux" -c "DROP EXTENSION IF EXISTS hstore"
            '';
          }
        );
      };
    };
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
  #           psql -d postgres -c "ALTER DATABASE coder REFRESH COLLATION VERSION;" 2>/dev/null || true
  #         '';
  #       }
  #     );
  #   };
  # };
}
