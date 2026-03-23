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
  ...
}: let
  cfg = config.services.anki-sync-server;
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/misc/anki-sync-server.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) listOf nullOr port str submodule;
  in {
    services.anki-sync-server = {
      enable = mkEnableOption "Anki Sync Server";

      package = mkPackageOption pkgs "anki-sync-server" {};

      settings = {
        base = mkOption {
          type = str;
          default = "%S/%N";
          description = "Base directory where user(s) synchronized data will be stored.";
        };

        host = mkOption {
          type = str;
          default = "::1";
          description = ''
            IP address Anki Sync Server listens to.
            Host names are not resolved.
          '';
        };

        port = mkOption {
          type = port;
          default = 8080;
          description = "Port number Anki Sync Server listens to.";
        };

        user = mkOption {
          type = listOf (submodule {
            options = {
              username = mkOption {
                type = str;
                description = "User name accepted by Anki Sync Server.";
              };
              password.cred = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  Encrypted password credential accepted by Anki Sync Server for the associated username.
                '';
              };
            };
          });
          description = "List of username-password pairs to provide to the Anki Sync Server.";
        };
      };
    };
  };

  config = let
    inherit (lib.attrsets) concatMapAttrs nameValuePair;
    inherit (lib.extra.systemd) mkSetCredentialEncrypted;
    inherit (lib.lists) singleton;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkDefault mkForce mkIf mkMerge;
    inherit (lib.strings) escapeShellArg toUpper;
  in
    mkIf cfg.enable {
      assertions = [
        {
          assertion = (builtins.length cfg.settings.user) > 0;
          message = "At least one username-password pair must be specified.";
        }
      ];

      systemd.services.anki-sync-server = {
        description = "Anki Sync Server";

        after = ["network.target"];

        wantedBy = ["multi-user.target"];

        path = [cfg.package];

        environment = {
          SYNC_BASE = cfg.settings.base;
          SYNC_HOST = cfg.settings.host;
          SYNC_PORT = toString cfg.settings.port;
        };

        serviceConfig = {
          Type = "simple";
          DynamicUser = true;
          StateDirectory = "anki";
          SetCredentialEncrypted = mkSetCredentialEncrypted cfg.settings.user;
          ExecStart = getExe (
            pkgs.custom.writeShell "anki-sync-server.bash" {
              env =
                cfg.settings.user
                |> concatMapAttrs (
                  user: cred: let
                    pass_var_name = "_SYNC_${user}_PASS";
                  in {
                    "${pass_var_name}".cred = user;
                    "SYNC_${user}" = "${user}:$${pass_var_name}";
                  }
                );

              text = ''
                exec ${lib.getExe cfg.package}
              '';
            }
          );
          Restart = "always";
        };
      };
    };

  meta = {
    maintainers = with lib.maintainers; [
      alexandrutocar
    ];
    doc = ./anki-sync-server.md;
  };
}
