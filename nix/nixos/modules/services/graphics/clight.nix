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
  inherit (lib.attrsets) filterAttrs isAttrs mapAttrsToList;
  inherit (lib.lists) isList;
  inherit (lib.strings) concatMapStringsSep concatStringsSep escape isString;
  inherit (lib.trivial) boolToString isInt isBool;

  cfg = config.services.clight;

  toConf = v:
    if builtins.isFloat v
    then toString v
    else if isInt v
    then toString v
    else if isBool v
    then boolToString v
    else if isString v
    then ''"${escape [''"''] v}"''
    else if isList v
    then "[ " + concatMapStringsSep ", " toConf v + " ]"
    else if isAttrs v
    then "\n{\n" + convertAttrs v + "\n}"
    else abort "clight.toConf: unexpected type (v = ${v})";

  getSep = v:
    if isAttrs v
    then ":"
    else "=";

  convertAttrs = attrs:
    concatStringsSep "\n" (mapAttrsToList
      (name: value: "${toString name} ${getSep value} ${toConf value};")
      attrs);

  clightConf = pkgs.writeText "clight.conf" (convertAttrs
    (filterAttrs
      (_: value: value != null)
      cfg.settings));
in {
  # This is a minimalist rewrite.
  disabledModules = [
    "services/x11/clight.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption mdDoc;
    inherit (lib.types) attrsOf bool either float listOf nullOr int oneOf str;
  in {
    services.clight = {
      enable = mkEnableOption (mdDoc "clight");

      package = mkPackageOption pkgs "clight" {};

      settings = let
        validConfigTypes = oneOf [int str bool float];
        collectionTypes = oneOf [validConfigTypes (listOf validConfigTypes)];
      in
        mkOption {
          type = attrsOf (nullOr (either collectionTypes (attrsOf collectionTypes)));
          default = {
            gamma.temp = [5500 3700];
          };
          example = {
            captures = 20;
            gamma_long_transition = true;
            ac_capture_timeouts = [120 300 60];
          };
          description = mdDoc ''
            See [clight.conf](https://github.com/FedeDP/Clight/blob/master/Extra/config/clight.conf) for a sample configuration file.
          '';
        };
    };
  };

  config = let
    inherit (lib.modules) mkIf;
    inherit (lib.meta) getExe;
  in
    mkIf cfg.enable {
      boot.kernelModules = [
        "i2c_dev"
      ];

      environment.systemPackages = with pkgs; [
        clightd
        clight
      ];

      services.dbus.packages = with pkgs; [
        clightd
        clight
      ];

      systemd.services = {
        clightd = {
          requires = ["polkit.service"];
          wantedBy = ["multi-user.target"];

          description = "Bus service to manage various screen related properties (gamma, dpms, backlight)";

          serviceConfig = {
            Type = "dbus";
            BusName = "org.clightd.clightd";
            Restart = "on-failure";
            RestartSec = 5;
            ExecStart = getExe pkgs.clightd;
          };
        };
      };

      systemd.user.services = {
        clight = {
          after = [
            "clightd.service"
          ];

          wants = [
            "clightd.service"
          ];

          partOf = [
            "graphical-session.target"
          ];
          wantedBy = [
            "graphical-session.target"
          ];

          description = "C daemon to adjust screen brightness to match ambient brightness, as computed capturing frames from webcam";
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 5;
            ExecStart = ''
              ${getExe cfg.package} --conf-file=${clightConf}
            '';
          };
        };
      };
    };
}
