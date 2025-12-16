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

  inherit (container) self x0-flx x0-pim;
in {
  services.postgresql = {
    enable = true;
    settings = {
      port = 5432;
      listen_addresses = mkForce self.address;
    };

    authentication = ''
      host  miniflux miniflux ${x0-flx.address}/32 trust
      host  davis davis ${x0-pim.address}/32 trust
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
    ];
    ensureDatabases = [
      "miniflux"
      "davis"
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
}
