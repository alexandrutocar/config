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
# spell-checker: ignore nmbd nsswins winbindd
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.samba;

  settingsFormat = let
    inherit (lib.strings) concatMapStringsSep;
    inherit (lib.generators) mkValueStringDefault;
  in
    pkgs.formats.ini {
      listToValue = concatMapStringsSep " " (mkValueStringDefault {});
    };
in let
  globalConfigFile = settingsFormat.generate "smb-global.conf" {
    global = cfg.settings.global;
  };
  sharesConfigFile = settingsFormat.generate "smb-shares.conf" (
    removeAttrs cfg.settings ["global"]
  );
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/network-filesystems/samba.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkPackageOption mkOption;
    inherit (lib.types) submodule;
  in {
    services.samba = {
      enable = mkEnableOption "Samba, the SMB/CIFS protocol";

      package = mkPackageOption pkgs "samba" {};

      settings = mkOption {
        type = submodule {
          freeformType = settingsFormat.type;
          options = {};
        };

        description = ''
          Refer to <https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html> for all available options.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Extra arguments to pass to the smbd service.";
      };
    };
  };

  config = let
    inherit (lib.meta) getExe';
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.strings) escapeShellArgs;
  in
    mkIf cfg.enable (mkMerge [
      {
        environment.etc."samba/smb.conf".source = pkgs.concatText "smb.conf" [
          globalConfigFile
          sharesConfigFile
        ];
      }
      {
        systemd = {
          slices.samba = {
            description = "Samba (SMB Networking Protocol) Slice";
          };
          targets.samba = {
            description = "Samba Server";
            after = ["network.target"];
            wants = ["network-online.target"];
            wantedBy = ["multi-user.target"];
          };
        };
      }
      {
        systemd.tmpfiles.settings."10-samba" = {
          "/var/cache/samba".d.mode = "0755";
          "/var/lock/samba".d.mode = "0755";
          "/var/log/samba".d.mode = "0755";
          "/var/lib/samba/private".d.mode = "0755";
        };
      }
      {
        security.pam.services.samba = {};

        security.wrappers = {
          "mount.cifs" = {
            program = "mount.cifs";
            source = getExe' pkgs.cifs-utils "mount.cifs";
            owner = "root";
            group = "root";
            setuid = true;
          };
        };
      }

      {
        environment.systemPackages = [cfg.package];

        systemd.services.smbd = {
          partOf = ["samba.target"];
          after = [
            "network.target"
            "network-online.target"
          ];

          wants = ["network-online.target"];

          wantedBy = ["samba.target"];

          description = "smbd";
          documentation = [
            "man:smbd(8)"
            "man:samba(7)"
            "man:smb.conf(5)"
          ];

          # environment.LD_LIBRARY_PATH = config.system.nssModules.path;

          unitConfig = {
            RequiresMountsFor = "/var/lib/samba";
          };

          serviceConfig = {
            ExecReload = "${getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
            ExecStart = "${cfg.package}/sbin/smbd --foreground --no-process-group ${escapeShellArgs cfg.extraArgs}";
            LimitCORE = "infinity";
            LimitNOFILE = 16384;
            PIDFile = "/run/samba/smbd.pid";
            Slice = "samba.slice";
            Type = "notify";
          };

          restartTriggers = [
            config.environment.etc."samba/smb.conf".source
          ];
        };
      }
    ]);

  meta = {
    doc = ./05-samba.md;
    maintainers = with lib.maintainers; [alexandrutocar];
  };
}
