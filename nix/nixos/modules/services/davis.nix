# Copyright (c) 2003-2025 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ────────────────────────────────────────────────────────────────────────
# NOTE: This module keeps the general structure of the upstream one but
#       applies a few adjustments tailored to my setup. Only the pieces
#       I actually use are kept; unused options have been trimmed. Some
#       defaults have been changed/removed to reduce noise and clutter.
# ────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.trivial) const;

  cfg = config.services.davis;

  toStringAttrs = mapAttrs (const toString);
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/web-apps/davis.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf bool int nullOr oneOf path str submodule;
    inherit (lib.strings) literalExpression;
  in {
    services.davis = {
      enable = mkEnableOption "Davis";

      package = mkPackageOption pkgs.custom "davis" {};

      logDir = mkOption {
        default = cfg.dataDir + "/log";
        description = "Davis' log directory.";
        type = path;
      };

      dataDir = mkOption {
        default = "/var/lib/davis";
        description = "Davis' data directory.";
        type = path;
      };

      cacheDir = mkOption {
        default = cfg.dataDir + "/cache";
        description = "Davis' cache directory.";
        type = path;
      };

      user = mkOption {
        default = "davis";
        description = "User Davis runs as.";
        type = str;
      };

      group = mkOption {
        default = "davis";
        description = "Group Davis runs as.";
        type = str;
      };

      settings = mkOption {
        type = attrsOf (oneOf [
          str
          int
          bool
        ]);

        default = {};

        description = ''
          Customize the default settings, refer to <https://github.com/tchapi/davis/blob/1a2e366c8700bcbe66a8d370d8c0b55b5bcb4b4c/.env>
          for details on supported values.
        '';
      };

      domain = mkOption {
        type = str;
        default = "davis";
        description = "FQDN for the Davis instance.";
        example = "davis.example.org";
      };

      nginx = mkOption {
        type = nullOr (
          submodule (import (modulesPath + "/services/web-servers/nginx/vhost-options.nix") {inherit config lib;})
        );
        default = {};
        description = ''
          With this option, you can customize an NGINX virtual host which already
          has sensible defaults for Davis. Set to `{ }` if you do not need any
          customization for the virtual host. If enabled, then by default, the
          {option}`serverName` is `''${domain}`. If this is set to null (the
          default), no NGINX virtual host will be configured.
        '';
        example = literalExpression ''
          {
            enableACME = true;
            forceHttps = true;
          }
        '';
      };

      phpfpm.settings = mkOption {
        type = attrsOf (oneOf [
          int
          str
          bool
        ]);

        default = {};

        description = ''
          Options for Davis's PHPFPM pool.
        '';
      };
    };
  };

  config = let
    inherit (lib.attrsets) mapAttrs;
    inherit (lib.lists) singleton;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkDefault mkForce mkIf mkMerge;
  in
    mkIf cfg.enable (mkMerge [
      {
        services.davis.settings = {
          ENV_DIR = cfg.dataDir;

          # Note: We do not need the log dir (we log to stdout/journald), by Symphony
          #       will try to create it, and the default value is one in the
          #       nix-store so we set it to a path under data directory to avoid
          #       something like: "Unable to create the 'logs' directory
          #       (/nix/store/5cfskz0ybbx37s1161gjn5klwb5si1zg-davis-4.4.1/var/log)".
          APP_LOG_DIR = cfg.logDir;
          APP_CACHE_DIR = cfg.cacheDir;
        };
      }
      {
        users = {
          users.${cfg.user} = {
            inherit (cfg) group;
            description = "Davis Service User";
            home = cfg.dataDir;
            isSystemUser = true;
          };
          groups.${cfg.group} = {};
        };

        systemd.tmpfiles.settings."25-davis" = {
          ${cfg.dataDir}.d = {
            inherit (cfg) user group;
            mode = "0710";
          };
          ${cfg.logDir}.d = {
            inherit (cfg) user group;
            mode = "0700";
          };
          ${cfg.cacheDir}.d = {
            inherit (cfg) user group;
            mode = "0700";
          };
        };
      }
      {
        # Create PHP Fast Process Manager Pool for the Davis Server.
        services.phpfpm.pools.davis = {
          inherit (cfg) group user;

          settings = mkMerge [
            {
              "listen.mode" = "0660";

              "pm" = "dynamic";

              "listen.owner" = config.services.nginx.user;
              "listen.group" = config.services.nginx.group;

              "pm.max_children" = 128;
              "pm.max_requests" = 256;
              "pm.start_servers" = 5;
              "pm.min_spare_servers" = 1;
              "pm.max_spare_servers" = 9;
            }
            cfg.phpfpm.settings
          ];

          phpEnv = mapAttrs (key: _: "$" + key) cfg.settings;
        };

        systemd.services."phpfpm-davis" = {
          serviceConfig.ReadWritePaths = [cfg.dataDir];

          environment = toStringAttrs cfg.settings;

          after = [
            "davis-environment.service"
            "davis-database-migrations.service"
          ];

          requires = [
            "davis-environment.service"
          ];
        };
      }
      {
        systemd.services.davis-environment = {
          description = "Davis' Environment";

          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;

            ExecStart = getExe (
              pkgs.custom.writeShell "davis-environment.bash" {
                text = ''
                  # Create `.env` file with the upstream values.
                  install -T -m 0600 -o ${cfg.user} ${cfg.package}/.env "${cfg.dataDir}/.env"
                '';
              }
            );
          };
          path = [pkgs.replace-secret];
          restartTriggers = [
            cfg.package
          ];
        };

        systemd.services.davis-database-migrations = {
          description = "Davis' Database Migrations";

          after = [
            "network-online.target"
            "davis-environment.service"
          ];

          wants = [
            "network-online.target"
          ];
          requires = [
            "davis-environment.service"
          ];

          wantedBy = ["multi-user.target"];

          serviceConfig = {
            ReadWritePaths = "${cfg.dataDir}";
            User = cfg.user;
            UMask = 77;
            DeviceAllow = "";
            LockPersonality = true;
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            PrivateUsers = true;
            ProcSubset = "pid";
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            RemoveIPC = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@resources"
              "~@privileged"
            ];
            WorkingDirectory = "${cfg.package}/";
            Type = "simple";
            RemainAfterExit = true;
            ExecStart = getExe (
              pkgs.custom.writeShell "davis-database-migrations.bash" {
                inputs = singleton cfg.package;
                text = ''
                  maximum=30
                  attempt=0

                  echo "Attempting to connect to database and run migrations..."

                  set +e
                  while [ $attempt -lt $maximum ]; do
                    attempt=$((attempt + 1))

                    echo "Attempt $attempt/$maximum..."

                    if console cache:clear --no-debug && console cache:warmup --no-debug && console doctrine:migrations:migrate; then
                      set -e
                      exit 0
                    fi

                    if [ $attempt -lt $maximum ]; then
                      echo "Failed to connect to database, retrying in 2 seconds..."
                      sleep 2
                    fi
                  done
                  set -e

                  echo "Failed to run migrations after $maximum attempts."
                  exit 1
                '';
              }
            );
          };
          restartTriggers = [
            cfg.package
          ];
          environment = toStringAttrs cfg.settings;
        };
      }
      {
        services.nginx = mkIf (cfg.nginx != null) {
          enable = mkDefault true;
          virtualHosts."${cfg.domain}" = mkMerge [
            {
              root = mkForce "${cfg.package}/public";
              locations = {
                "/" = {
                  extraConfig = ''
                    try_files $uri $uri/ /index.php$is_args$args;
                  '';
                };
                "~* ^/.well-known/(caldav|carddav)$" = {
                  extraConfig = ''
                    return 302 https://$host/dav/;
                  '';
                };
                "~ ^(.+\\.php)(.*)$" = {
                  extraConfig = ''
                    try_files                $fastcgi_script_name =404;
                    include                  ${config.services.nginx.package}/conf/fastcgi_params;
                    include                  ${config.services.nginx.package}/conf/fastcgi.conf;
                    fastcgi_pass             unix:${config.services.phpfpm.pools.davis.socket};
                    fastcgi_param            SCRIPT_FILENAME  $document_root$fastcgi_script_name;
                    fastcgi_param            PATH_INFO        $fastcgi_path_info;
                    fastcgi_split_path_info  ^(.+\.php)(.*)$;
                    fastcgi_param            X-Forwarded-Proto https;
                    fastcgi_param            X-Forwarded-Port $http_x_forwarded_port;
                  '';
                };
                "~ /(\\.ht)" = {
                  extraConfig = ''
                    deny all;
                    return 404;
                  '';
                };
              };
              extraConfig = ''
                charset utf-8;
                index index.php;
              '';
            }
            cfg.nginx
          ];
        };
      }
    ]);

  meta = {
    doc = ./davis.md;
    maintainers = pkgs.davis.meta.maintainers;
  };
}
