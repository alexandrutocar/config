{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.custom.services.backup;
in {
  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf listOf path str submodule;
  in {
    custom.services.backup = {
      enable = mkEnableOption "Automatic backup with Restic";
      package = mkPackageOption pkgs "restic" {};
      periodic = mkOption {
        type = attrsOf (submodule [
          ({name, ...}: {
            options = {
              target = mkOption {
                type = path;
                description = ''
                  Directory that is the target of backup.
                '';
              };
              flags = mkOption {
                type = listOf str;
                default = [];
                description = ''
                  Flags passed to backup command.
                '';
              };
              exclude = mkOption {
                type = listOf str;
                default = [];
                example = [
                  "/var/cache"
                  "/home/*/.cache"
                  ".git"
                ];
                description = ''
                  Patterns to exclude when backing up. See
                  <https://restic.readthedocs.io/en/stable/040_backup.html#excluding-files> for
                  details on syntax.
                '';
              };
              # -DEVELOPERS ONLY-
              name = mkOption {
                type = str;
                internal = true;
                default = name;
                visible = false;
                readOnly = true;
                description = ''
                  Unique identifier of the backup. This is set to the
                  attribute name of the backup configuration.
                '';
              };
              serviceUnitName = mkOption {
                type = str;
                internal = true;
                default = "backup@${name}";
                visible = false;
                readOnly = true;
                description = ''
                  Unique service unit name of the backup. This is useful
                  when providing credentials or setting environment.
                '';
              };
            };
          })
        ]);
        default = {};
        description = "List of periodic backup targets.";
      };
    };
  };

  config = let
    inherit (lib.attrsets) mapAttrs' mapAttrsToList nameValuePair;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.strings) concatStringsSep escapeShellArg;
  in
    mkIf cfg.enable (mkMerge [
      {
        assertions =
          cfg.periodic
          |> mapAttrsToList (name: backupConfig: {
            assertion = backupConfig.target != null;
            message = "services.restic.backups.target: backup must have a target";
          });
      }
      {
        systemd.user.services."backup@" = {};
      }
      {
        systemd.user.services =
          cfg.periodic
          |> mapAttrs' (
            identifier: settings:
              nameValuePair settings.serviceUnitName {
                Unit = {
                  Description = "Restic Backup for '${identifier}'";
                  Wants = ["network-online.target"];
                  After = ["network-online.target"];
                };

                Service = {
                  Type = "oneshot";

                  X-RestartIfChanged = true;
                  RuntimeDirectory = "backup/${identifier}";
                  CacheDirectory = "backup/${identifier}";
                  CacheDirectoryMode = "0700";
                  PrivateTmp = true;

                  ExecStart = getExe (
                    pkgs.custom.writeShell "backup@${identifier}.bash" {
                      env = {
                        AWS_ACCESS_KEY_ID.cred = "aws-access-key-id";
                        AWS_SECRET_ACCESS_KEY.cred = "aws-secret-access-key";
                        RESTIC_PASSWORD.cred = "restic-password";
                        RESTIC_REPOSITORY.cred = "restic-repository";
                      };
                      text = ''
                        restic backup ${escapeShellArg settings.target} ${concatStringsSep " " settings.flags}
                      '';
                      inputs = with pkgs; [restic];
                    }
                  );
                };
              }
          );
      }
      {
        systemd.user.timers =
          cfg.periodic
          |> mapAttrs' (
            identifier: settings:
              nameValuePair settings.serviceUnitName {
                Unit.Description = "Restic Backup for '${identifier}'";
                Install.WantedBy = ["timers.target"];
              }
          );
      }
    ]);
}
