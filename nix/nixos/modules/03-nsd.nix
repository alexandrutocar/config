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
  pkgs,
  lib,
  ...
}: let
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.debug) traceSeq;
  inherit (lib.strings) concatStringsSep concatMapStringsSep literalExpression;
  inherit (lib.trivial) boolToYesNo;
  inherit (lib) isAttrs isBool isList isInt isString;

  cfg = config.services.nsd;

  toOption = indent: n: v: "${indent}${toString n}: ${v}";

  toConf = indent: n: v:
    if builtins.isFloat v
    then (toOption indent n (builtins.toJSON v))
    else if isInt v
    then (toOption indent n (toString v))
    else if isBool v
    then (toOption indent n (boolToYesNo v))
    else if isString v
    then (toOption indent n v)
    else if isList v
    then (concatMapStringsSep "\n" (toConf indent n) v)
    else if isAttrs v
    then (concatStringsSep "\n" (["${indent}${n}:"] ++ (mapAttrsToList (toConf "${indent}  ") v)))
    else throw (traceSeq v "services.nsd.settings: unexpected type");

  confNoServer = concatStringsSep "\n" (
    (mapAttrsToList (toConf "") (removeAttrs cfg.settings ["server"])) ++ [""]
  );
  confServer = concatStringsSep "\n" (
    mapAttrsToList (toConf "  ") cfg.settings.server
  );

  confFileUnchecked = pkgs.writeText "cfg.conf" ''
    server:
    ${confServer}
    ${confNoServer}
  '';

  confFile =
    pkgs.runCommandLocal "nsd-checkconf"
    ''
      cp ${confFileUnchecked} nsd.conf

      # fake stateDir which is not accessible in the sandbox
      mkdir -p $PWD/state
      sed -i nsd.conf \
        -e '/auto-trust-anchor-file/d' \
        -e "s|${cfg.stateDir}|$PWD/state|"
      ${cfg.package}/bin/nsd-checkconf nsd.conf

      cp ${confFileUnchecked} $out
    '';

  finalPackage = cfg.package.override {
    ratelimit = true;
    zoneStats = true;
  };
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/networking/nsd.nix"
  ];

  options = let
    inherit (lib.types) attrsOf bool float int listOf oneOf path str submodule;
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
  in {
    services.nsd = {
      enable = mkEnableOption "Name Server Daemon";

      package = mkPackageOption pkgs "nsd" {};

      user = mkOption {
        type = str;
        default = "nsd";
        description = "User account under which NSD runs.";
      };

      group = mkOption {
        type = str;
        default = "nsd";
        description = "Group under which NSD runs.";
      };

      pidFile = mkOption {
        type = str;
        default = "${cfg.stateDir}/var/nsd.pid";
        description = "Process file with  which NSD runs.";
      };

      stateDir = mkOption {
        type = path;
        default = "/var/lib/nsd";
        description = "Directory holding all state for NSD to run.";
      };

      settings = mkOption {
        default = {};
        type = submodule {
          freeformType = let
            validSettingsPrimitiveTypes = oneOf [
              int
              str
              bool
              float
            ];
            validSettingsTypes = oneOf [
              validSettingsPrimitiveTypes
              (listOf validSettingsPrimitiveTypes)
            ];
            settingsType = oneOf [
              str
              (attrsOf validSettingsTypes)
            ];
          in
            attrsOf (oneOf [
              settingsType
              (listOf settingsType)
            ])
            // {
              description = ''
                nsd.conf configuration type. The format consist of an attribute
                set of settings. Each settings can be either one value, a list of
                values or an attribute set. The allowed values are integers,
                strings, booleans or floats.
              '';
            };

          options = {
            remote-control.control-enable = mkOption {
              type = bool;
              default = false;
              internal = true;
            };
          };
        };
        example = literalExpression ''
          {
            server = {
              interface = [ "127.0.0.1" ];
            };
            zone = [{
              name = \'\'"ueuie.dev"\'\';
              zonefile = \'\'"/var/lib/nsd/zones/%s.zone"\'\';
            }];
            remote-control.control-enable = true;
          };
        '';
        description = ''
          Declarative NSD configuration
          See the {manpage}`nsd.conf(5)` manpage for a list of
          available options.
        '';
      };
    };
  };

  config = let
    inherit (lib.modules) mkDefault mkIf;
    inherit (lib.lists) optional;
  in
    mkIf cfg.enable {
      services.nsd.settings = {
        server = {
          chroot = ''"${cfg.stateDir}"'';
          username = "${cfg.user}";

          # Directory for 'zonefile:' files.
          zonesdir = ''"${cfg.stateDir}"'';

          # List of dynamically added zones.
          pidfile = ''"${cfg.pidFile}"'';
          xfrdfile = ''"${cfg.stateDir}/var/xfrd.state"'';
          xfrdir = ''"${cfg.stateDir}/tmp"'';
          zonelistfile = ''"${cfg.stateDir}/var/zone.list"'';
        };

        remote-control = {
          control-enable = mkDefault false;
          control-interface = mkDefault (["127.0.0.1"] ++ (optional config.networking.enableIPv6 "::1"));
        };
      };

      environment = {
        systemPackages = [finalPackage];
        etc."nsd/nsd.conf".source = "${confFile}";
      };

      users.groups.${cfg.group}.gid = config.ids.gids.nsd;

      users.users.${cfg.user} = {
        description = "NSD service user";
        home = cfg.stateDir;
        createHome = true;
        uid = config.ids.uids.nsd;
        inherit (cfg) group;
      };

      systemd.services.nsd = {
        description = "NSD authoritative only domain name service";

        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        startLimitBurst = 4;
        startLimitIntervalSec = 5 * 60; # 5 mins
        serviceConfig = {
          ExecStart = "${finalPackage}/sbin/nsd -d -c ${confFile}";
          StandardError = "null";
          PIDFile = cfg.pidFile;
          Restart = "always";
          RestartSec = "4s";
        };

        preStart = ''
          rm -Rf "${cfg.stateDir}/private/"
          rm -Rf "${cfg.stateDir}/tmp/"

          install -dm 0700 -o "${cfg.user}" -g "${cfg.user}" "${cfg.stateDir}/private"
          install -dm 0700 -o "${cfg.user}" -g "${cfg.user}" "${cfg.stateDir}/tmp"
          install -dm 0700 -o "${cfg.user}" -g "${cfg.user}" "${cfg.stateDir}/var"
        '';
      };
    };
}
