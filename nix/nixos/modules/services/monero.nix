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
  inherit (lib.generators) mkKeyValueDefault toKeyValue;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.services.monero;
  # toConfig = toKeyValue {
  #   listsAsDuplicateKeys = true;
  # };
  # config = toConfig (mkMerge [
  #   {
  #     log-file = "/dev/stdout";
  #     # data-dir = cfg.settings.data-dir;
  #   }
  #   (mkIf cfg.settings.mining.enable {
  #     start-mining = cfg.address;
  #     mining-threads = toString cfg.settings.mining.threads;
  #   })
  #   {
  #     rpc-bind-ip = cfg.settings.rpc.address;
  #     rpc-bind-port = cfg.settings.rpc.port;
  #   }
  #   (mkIf (cfg.settings.rpc.user
  #     != null
  #     && cfg.rpc.password
  #     != null) {
  #     rpc-login = "${cfg.settings.rpc.user}:${cfg.settings.rpc.password}";
  #   })
  #   (mkIf cfg.settings.rpc.restricted {
  #     restricted-rpc = 1;
  #   })
  #   (mkIf cfg.settings.ban-list
  #     != [] {
  #       ban-list = cfg.settings.ban-list;
  #     })
  # ]);
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/networking/monero.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) addCheck bool int lines listOf nullOr path port str;
    inherit (lib.types.ints) unsigned;
  in {
    services.monero = {
      enable = mkEnableOption "Monero Daemon";

      package = mkPackageOption pkgs "monerod" {};

      settings = {
        data-dir = mkOption {
          type = path;
          default = "/var/lib/monero";
          description = ''
            The directory where Monero stores its data files.
          '';
        };

        ban-list = mkOption {
          type = nullOr path;
          default = null;
          description = ''
            Path to a text file containing IPs to block.
            Useful to prevent DDoS/deanonymization attacks.

            <https://github.com/monero-project/meta/issues/1124>
          '';
          example = lib.literalExpression ''
            builtins.fetchurl {
              url = "https://raw.githubusercontent.com/rblaine95/monero-banlist/c6eb9413ddc777e7072d822f49923df0b2a94d88/block.txt";
              hash = "";
            };
          '';
        };

        limits = {
          download = mkOption {
            type = addCheck int (x: x >= -1);
            default = -1;
            description = ''
              Limit of the download rate in kB/s.
              Set to `-1` to leave unlimited.
            '';
          };

          syncSize = mkOption {
            type = unsigned;
            default = 0;
            description = ''
              Maximum number of blocks to sync at once.
              Set to `0` for adaptive.
            '';
          };

          threads = mkOption {
            type = unsigned;
            default = 0;
            description = ''
              Maximum number of threads used for a parallel job.
              Set to `0` to leave unlimited.
            '';
          };

          upload = mkOption {
            type = addCheck int (x: x >= -1);
            default = -1;
            description = ''
              Limit of the upload rate in kB/s.
              Set to `-1` to leave unlimited.
            '';
          };
        };

        mining = {
          enable = mkOption {
            type = bool;
            default = false;
            description = ''
              Whether to mine monero.
            '';
          };

          address = mkOption {
            type = str;
            default = "";
            description = ''
              Monero address where to send mining rewards.
            '';
          };

          threads = mkOption {
            type = unsigned;
            default = 0;
            description = ''
              Number of threads used for mining.
              Set to `0` to use all available.
            '';
          };
        };

        rpc = {
          address = mkOption {
            type = str;
            default = "127.0.0.1";
            description = ''
              IP address the RPC server will bind to.
            '';
          };

          password = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              Password for RPC connections.
            '';
          };

          port = mkOption {
            type = port;
            default = 18081;
            description = ''
              Port the RPC server will bind to.
            '';
          };

          restricted = mkOption {
            type = bool;
            default = false;
            description = ''
              Whether to restrict RPC to view only commands.
            '';
          };

          user = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              User name for RPC connections.
            '';
          };
        };
      };
    };
  };

  config = let
    inherit (lib.modules) mkIf mkMerge;
  in
    mkIf cfg.enable (mkMerge [
      {
        users.groups.monero = {};

        users.users.monero = {
          isSystemUser = true;
          group = "monero";
          description = "Monero Daemon";
          home = cfg.settings.data-dir;
          createHome = true;
        };
      }
      {
        systemd.services.monero = {
          description = "Monero Daemon";

          after = ["network.target"];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            User = "monero";
            Group = "monero";

            ExecStart = "${lib.getExe' cfg.package "monerod"} --config-file=${cfg.settings.data-dir}/monerod.conf --non-interactive";
            Restart = "always";

            SuccessExitStatus = [0 1];
          };
        };

        assertions = lib.singleton {
          assertion = cfg.settings.mining.enable -> cfg.settings.mining.address != "";
          message = ''
            You need a Monero address to receive mining rewards:
            specify one using option monero.mining.address.
          '';
        };
      }
    ]);
}
