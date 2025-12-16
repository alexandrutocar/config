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
  inherit (lib.generators) toINI toINIWithGlobalSection;

  cfg = config.i18n.inputMethod.fcitx5;

  finalPackage = pkgs.qt6Packages.fcitx5-with-addons.override {
    inherit (cfg) addons;
  };

  iniFormat = pkgs.formats.ini {};
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "i18n/input-method/fcitx5.nix"
  ];

  options = let
    inherit (lib.options) literalExpression mkOption;

    inherit (lib.types) listOf package path submodule attrsOf anything;
  in {
    i18n.inputMethod.fcitx5 = {
      addons = mkOption {
        type = listOf package;
        default = [];
        example = literalExpression "with pkgs; [ fcitx5-rime ]";
        description = ''
          Enabled Fcitx5 addons.
        '';
      };
      phrases = mkOption {
        type = listOf path;
        default = [];
        example = literalExpression ''
          [./words.mb ./numbers.mb]
        '';
        description = "Quick phrase files.";
      };
      settings = {
        config = mkOption {
          type = submodule {
            freeformType = iniFormat.type;
          };
          default = {};
          description = ''
            The global options in `config` file in ini format.
          '';
        };
        profile = mkOption {
          type = submodule {
            freeformType = iniFormat.type;
          };
          default = {};
          description = ''
            The input method configure in `profile` file in ini format.
          '';
        };
        addons = mkOption {
          type = attrsOf anything;
          default = {};
          description = ''
            The addon configures in `conf` folder in ini format with global sections.
            Each item is written to the corresponding file.
          '';
          example = literalExpression "{ pinyin.globalSection.EmojiEnabled = \"True\"; }";
        };
      };
    };
  };

  config = let
    inherit (lib.attrsets) concatMapAttrs mergeAttrsList optionalAttrs;
    inherit (lib.lists) optionals;
    inherit (lib.modules) mkIf;
  in
    mkIf (config.i18n.inputMethod.enable && config.i18n.inputMethod.type == "fcitx5") {
      i18n.inputMethod.package = finalPackage;

      i18n.inputMethod.fcitx5.addons = optionals (cfg.phrases != []) [
        (
          pkgs.linkFarm "phrases" (
            builtins.listToAttrs (
              builtins.map (
                path: {
                  name = "share/fcitx5/data/quickphrase.d/${builtins.baseNameOf builtins.toString path}.mb";
                  value = path;
                }
              )
              cfg.phrases
            )
          )
        )
      ];
      environment.etc = let
        optionalFile = name: generator: config:
          optionalAttrs (config != {}) {
            "xdg/fcitx5/${name}".text = generator config;
          };
      in
        mergeAttrsList [
          (optionalFile "config" (toINI {}) cfg.settings.config)
          (optionalFile "profile" (toINI {}) cfg.settings.profile)
          (
            concatMapAttrs (
              name: value: optionalFile "conf/${name}.conf" (toINIWithGlobalSection {}) value
            )
            cfg.settings.addons
          )
        ];

      environment.variables = {
        XMODIFIERS = "@im=fcitx";
        QT_PLUGIN_PATH = ["${finalPackage}/${pkgs.qt6.qtbase.qtPluginPrefix}"];
      };
    };
}
