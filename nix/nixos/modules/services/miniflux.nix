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
  cfg = config.services.miniflux;

  boolToInt = b:
    if b
    then 1
    else 0;
in {
  # This is a minimalist rewrite.
  disabledModules = [
    "services/web-apps/miniflux.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf bool coercedTo int oneOf str submodule;
  in {
    services.miniflux = {
      enable = mkEnableOption "miniflux";

      package = mkPackageOption pkgs "miniflux" {};

      settings = mkOption {
        type = submodule {
          freeformType = attrsOf (oneOf [
            str
            int
          ]);
          options = {
            LISTEN_ADDR = mkOption {
              type = str;
              default = "localhost:8080";
              description = ''
                Address to listen on. Use absolute path for a Unix socket.
                Multiple addresses can be specified, separated by commas.
              '';
              example = "127.0.0.1:8080, 127.0.0.1:8081";
            };
            RUN_MIGRATIONS = mkOption {
              type = coercedTo bool boolToInt int;
              default = true;
              description = "Run database migrations.";
            };
            WATCHDOG = mkOption {
              type = coercedTo bool boolToInt int;
              default = true;
              description = "Enable or disable Systemd watchdog.";
            };
          };
        };
        default = {};
        description = ''
          Configuration for Miniflux, refer to
          <https://miniflux.app/docs/configuration.html>
          for documentation on the supported values.
        '';
      };
    };
  };

  config = let
    inherit (lib.attrsets) mapAttrs;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf;
  in
    mkIf cfg.enable {
      systemd.services.miniflux = {
        description = "Miniflux";
        wantedBy = ["multi-user.target"];
        after = [
          "network.target"
        ];

        serviceConfig = {
          Type = "notify";
          ExecStart = getExe cfg.package;
          User = "miniflux";
          DynamicUser = true;
          RuntimeDirectory = "miniflux";
          RuntimeDirectoryMode = "0750";
          WatchdogSec = 60;
          WatchdogSignal = "SIGKILL";
          Restart = "always";
          RestartSec = 5;

          # Hardening
          CapabilityBoundingSet = [""];
          DeviceAllow = [""];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          PrivateDevices = true;
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
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          UMask = "0077";
        };

        environment = mapAttrs (_: toString) cfg.settings;
      };
      environment.systemPackages = [cfg.package];

      security.apparmor.policies."bin.miniflux".profile = ''
        abi <abi/4.0>,
        include <tunables/global>

        profile ${cfg.package}/bin/miniflux {
          include <abstractions/base>
          include <abstractions/nameservice>
          include <abstractions/ssl_certs>
          include <abstractions/golang>
          include "${pkgs.apparmorRulesFromClosure {name = "miniflux";} cfg.package}"
          ${cfg.package}/bin/miniflux r,
          /run/miniflux/** rw,
          include if exists <local/bin.miniflux>
        }
      '';
    };
}
