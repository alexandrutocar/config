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
  inherit (lib.lists) isList;
  inherit (lib.meta) getExe;
  inherit (lib.strings) optionalString;
  inherit (lib.trivial) boolToString isBool;

  cfg = config.programs.bat;

  recursiveToString = value:
    if isList value
    then map recursiveToString value
    else if isBool value
    then boolToString value
    else toString value;

  keyValueFormat = pkgs.formats.keyValue {listsAsDuplicateKeys = true;};

  initScript = {
    program,
    flags ? [],
  }: ''
    ${getExe program} ${toString flags} | source
  '';

  shellInit = shell:
    optionalString (builtins.elem pkgs.bat-extras.batpipe cfg.scripts) (initScript {
      program = pkgs.bat-extras.batpipe;
      inherit shell;
    })
    + optionalString (builtins.elem pkgs.bat-extras.batman cfg.scripts) (initScript {
      program = pkgs.bat-extras.batman;
      inherit shell;
      flags = ["--export-env"];
    });
in {
  # Disabled the original upstream module
  # since this is a simplified rewrite.
  disabledModules = [
    "programs/bat.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkPackageOption mkOption literalExpression;
    inherit (lib.types) listOf package;
  in {
    programs.bat = {
      enable = mkEnableOption "`bat`, a {manpage}`cat(1)` clone with wings";

      package = mkPackageOption pkgs "bat" {};

      scripts = mkOption {
        default = [];
        example = literalExpression ''
          with pkgs.bat-extras; [
            batdiff
            batgrep
          ];
        '';
        description = ''
          Extra `bat` scripts.
        '';
        type = listOf package;
      };

      settings = mkOption {
        inherit (keyValueFormat) type;

        description = ''
          System-wide `bat` configuration file.
        '';
        default = {};
        example = {
          theme = "ansi";
          italic-text = "always";
          paging = "never";
          pager = "less --RAW-CONTROL-CHARS --quit-if-one-screen --mouse";
          map-syntax = [
            "*.ino:C++"
            ".ignore:Git Ignore"
          ];
        };
      };
    };
  };

  config = let
    inherit (lib.attrsets) mapAttrs' nameValuePair;
    inherit (lib.modules) mkIf;
  in
    mkIf cfg.enable {
      environment = {
        systemPackages = [cfg.package] ++ cfg.scripts;

        etc."bat/config".source = keyValueFormat.generate "config" (
          mapAttrs' (name: value: nameValuePair ("--" + name) (recursiveToString value)) cfg.settings
        );
      };

      programs = {
        bash = {
          interactiveShellInit = shellInit "bash";
        };
        zsh = {
          interactiveShellInit = shellInit "zsh";
        };
      };
    };
}
