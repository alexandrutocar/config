{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.glue;
in {
  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf str submodule;
  in {
    services.glue = {
      enable = mkEnableOption "glue";
      package = mkPackageOption pkgs.custom.scripts.extras "glue" {};
      settings = mkOption {
        type = attrsOf (submodule [
          ({name, ...}: {
            options = {
              glue-prefix = mkOption {
                type = str;
                example = "ns1";
                description = ''
                  Glue-Prefix that is going to be updated.
                  Use @ if your DNS servers are hosted under the root domain.
                '';
              };

              ipv4 =
                mkEnableOption ""
                // {
                  description = ''
                    Whether to query and update IPv4 addresses.
                  '';
                  default = true;
                  example = false;
                };

              ipv6 =
                mkEnableOption ""
                // {
                  description = ''
                    Whether to query and update IPv6 addresses.
                  '';
                  default = config.networking.enableIPv6;
                  example = false;
                };

              # -DEVELOPERS ONLY-
              name = mkOption {
                type = str;
                internal = true;
                default = name;
                visible = false;
                readOnly = true;
                description = ''
                  Root domain. This is set to the
                  attribute name of the glue record update configuration.
                '';
              };
              serviceUnitName = mkOption {
                type = str;
                internal = true;
                default = "glue@${name}";
                visible = false;
                readOnly = true;
                description = ''
                  Unique service unit name of the record update. This is useful
                  when providing credentials or setting environment.
                '';
              };
            };
          })
        ]);
        default = {};
        description = "List of Root domains whose Glue Records are to be updated.";
      };
    };
  };

  config = let
    inherit (lib.attrsets) mapAttrs' nameValuePair;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf mkMerge;
  in
    mkIf cfg.enable (mkMerge [
      {
        systemd.services =
          cfg.settings
          |> mapAttrs' (
            identifier: settings:
              nameValuePair settings.serviceUnitName {
                description = "Glue Records Update for '${identifier}'";

                after = [
                  "network-online.target"
                ];

                requires = [
                  "network-online.target"
                ];

                wantedBy = ["multi-user.target"];

                serviceConfig = {
                  Type = "oneshot";

                  StandardOutput = "journal";
                  StandardError = "journal";

                  User = "root";
                  Group = "root";

                  ExecStart = getExe (
                    pkgs.custom.writeShell "glue@${identifier}.bash" {
                      env = {
                        PORKBUN_API_TOKEN.cred = "porkbun-api-token";
                        PORKBUN_API_SECRET.cred = "porkbun-api-secret";

                        ENABLE_IPv4 =
                          if settings.ipv4
                          then "yes"
                          else "no";
                        ENABLE_IPv6 =
                          if settings.ipv6
                          then "yes"
                          else "no";

                        ROOT_DOMAIN = identifier;
                        GLUE_PREFIX = settings.glue-prefix;
                      };
                      text = ''
                        exec ${getExe cfg.package}
                      '';
                    }
                  );
                };
              }
          );
      }
      {
        systemd.user.timers =
          cfg.settings
          |> mapAttrs' (
            identifier: settings:
              nameValuePair settings.serviceUnitName {
                wantedBy = ["timers.target"];
                description = "Glue record update for '${identifier}'";
              }
          );
      }
    ]);
}
