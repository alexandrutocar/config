# MIT License
#
# Copyright (c) 2017-2025 Home Manager contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
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
  cfg = config.programs.zellij;
  settingsFormat = pkgs.formats.kdl {
    version = 1;
  };
in {
  disabledModules = [
    "programs/zellij.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf bool listOf literalExpression oneOf package path;
    inherit (lib.hm.shell) mkBashIntegrationOption mkZshIntegrationOption;
  in {
    programs.zellij = {
      enable = mkEnableOption "Zellij";

      package = mkPackageOption pkgs "zellij" {};

      settings = lib.mkOption {
        inherit (settingsFormat) type;
        default = [];
        example = literalExpression ''
          let
            inherit (settingsFormat.lib) node typed;
          in [
            (node "theme" null [ "custom" ] { } [ ])
            (node "themes" null [ ] { } [
              (node "custom" null [ ] { } [
                (node "fg" null [ "#ffffff" ] { } [ ])
              ])
            ])
            (node "keybinds" null [ ] { "clear-defaults" = true; } [
              (node "pane" null [ ] { } [
                (node "bind" null [ "e" ] { } [
                  (node "TogglePaneEmbedOrFloating" null [ ] { } [ ])
                  (node "SwitchToMode" null [ "locked" ] { } [ ])
                ])
                (node "bind" null [ "left" ] { } [
                  (node "MoveFocus" null [ "left" ] { } [ ])
                ])
              ])
            ])
          ]
        '';
        description = ''
          Configuration written to {file}`$XDG_CONFIG_HOME/zellij/config.kdl`.

          See <https://zellij.dev/documentation> for the full list of options.
        '';
      };

      # Configuration
      # -------------
      layouts = mkOption {
        type = attrsOf (oneOf [settingsFormat.type path]);
        default = {};
        example = literalExpression ''
          let
            inherit (settingsFormat.lib) node typed;
          in {
            dev = [
              (node "layout" null [ ] { } [
                (node "default_tab_template" null [ ] { } [
                  (node "pane" null [ ] { size = 1; borderless = true; } [
                    (node "plugin" null [ ] { location = "zellij:tab-bar"; } [ ])
                  ])
                  (node "children" null [ ] { } [ ])
                  (node "pane" null [ ] { size = 2; borderless = true; } [
                    (node "plugin" null [ ] { location = "zellij:status-bar"; } [ ])
                  ])
                ])
                (node "tab" null [ ] { name = "Project"; focus = true; } [
                  (node "pane" null [ ] { command = "nvim"; } [ ])
                ])
                (node "tab" null [ ] { name = "Git"; } [
                  (node "pane" null [ ] { command = "lazygit"; } [ ])
                ])
                (node "tab" null [ ] { name = "Files"; } [
                  (node "pane" null [ ] { command = "yazi"; } [ ])
                ])
                (node "tab" null [ ] { name = "Shell"; } [
                  (node "pane" null [ ] { command = "zsh"; } [ ])
                ])
              ])
            ];
          }
        '';
        description = ''
          Configuration written to {file}`$XDG_CONFIG_HOME/zellij/layouts/<layout>.kdl`.

          See <https://zellij.dev/documentation> for the full list of options.
        '';
      };

      themes = mkOption {
        type = attrsOf (oneOf [settingsFormat.type path]);
        default = {};
        description = ''
          Each them is written to {file}`$XDG_CONFIG_HOME/zellij/themes/<theme>.kdl`.

          See <https://zellij.dev/documentation/themes.html> for more information.
        '';
      };

      plugins = mkOption {
        type = listOf package;
        default = [];
        example = literalExpression ''
          with pkgs.zellijPlugins; [ jbz vim-plugins-navigator zjstatus ]
        '';
        description = "List of Zellij plugins";
      };

      # Shell Integration
      # -----------------
      enableBashIntegration = mkBashIntegrationOption {inherit config;};

      enableZshIntegration = mkZshIntegrationOption {inherit config;};

      exitShellOnExit = mkOption {
        type = bool;
        default = true;
        description = ''
          Whether to exit the shell when Zellij exits after being autostarted.

          Variable is checked in `auto-start` script.

          Requires shell integration to be enabled to have effect.
        '';
      };

      attachExistingSession = mkOption {
        type = bool;
        default = true;
        description = ''
          Whether to attach to the default session after being autostarted if a Zellij session already exists.

          Variable is checked in `auto-start` script.

          Requires shell integration to be enabled to have effect.
        '';
      };

      # Read-only/Internal Options
      # --------------------------
      finalPackage = mkOption {
        type = package;
        visible = false;
        readOnly = true;
        description = ''
          The Zellij package with all plugin dependencies.
        '';
      };
    };
  };

  config = let
    inherit (lib.attrsets) listToAttrs mapAttrs' nameValuePair;
    inherit (lib.lists) concatLists optional optionals;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf mkMerge mkOrder;
    inherit (lib.strings) isStorePath removePrefix;
    inherit (lib.trivial) boolToString;
  in let
    shellIntegrationEnabled = cfg.enableBashIntegration || cfg.enableZshIntegration;
  in
    mkIf cfg.enable (mkMerge [
      {
        assertions = [
          {
            assertion = !cfg.attachExistingSession || shellIntegrationEnabled;
            message = "You have enabled `programs.zellij.attachExistingSession`, but none of the shell integrations are enabled.";
          }
          {
            assertion = !cfg.exitShellOnExit || shellIntegrationEnabled;
            message = "You have enabled `programs.zellij.exitShellOnExit`, but none of the shell integrations are enabled.";
          }
        ];
      }
      (let
        pluginsRuntimeDeps = concatLists (
          map ({plugin, ...}: plugin.runtimeDeps or []) pluginsWithNames
        );

        pluginsWithNames =
          map (plugin: {
            inherit plugin;
            name = removePrefix "zellij-" plugin.pname;
          })
          cfg.plugins;
      in let
        pluginsSettings = let
          inherit (settingsFormat.lib) node;
        in
          optionals (pluginsWithNames != []) [
            (node "plugins" null [] {} (
              map (
                {name, ...}:
                  node name null [] {
                    location = "file:${config.xdg.configHome}/zellij/plugins/${name}.wasm";
                  } []
              )
              pluginsWithNames
            ))
            (node "load_plugins" null [] {} (
              map ({name, ...}: node name null [] {} []) pluginsWithNames
            ))
          ];
      in let
        renderedSettings = cfg.settings ++ pluginsSettings;
      in {
        programs.zellij.finalPackage =
          if pluginsRuntimeDeps != []
          then
            cfg.package.override {
              extraPackages = pluginsRuntimeDeps;
            }
          else cfg.package;

        home.packages = [cfg.finalPackage];

        xdg.configFile = mkMerge [
          {
            "zellij/config.kdl" = {
              text = builtins.readFile (settingsFormat.generate "config.kdl" renderedSettings);
            };
          }

          (mapAttrs' (
              name: value:
                nameValuePair "zellij/layouts/${name}.kdl" {
                  source =
                    if builtins.isPath value || isStorePath value
                    then value
                    else settingsFormat.generate "zellij-layout-${name}.kdl" value;
                }
            )
            cfg.layouts)

          (mapAttrs' (
              name: value:
                nameValuePair "zellij/themes/${name}.kdl" {
                  source =
                    if builtins.isPath value || isStorePath value
                    then value
                    else
                      pkgs.writeText "zellij-theme-${name}" (
                        if builtins.isString value
                        then value
                        else (builtins.readFile (settingsFormat.generate "zellij-theme-${name}.kdl" value))
                      );
                }
            )
            cfg.themes)

          # on every plugin update, zellij asks for permissions again, because
          # the plugin path has changed (=/nix/store path has changed)
          # to avoid that, we symlink all plugins to `.config/zellij/plugins` and
          # use those paths
          (listToAttrs (
            map (
              {
                plugin,
                name,
              }: {
                name = "zellij/plugins/${name}.wasm";
                value.source = plugin;
              }
            )
            pluginsWithNames
          ))
        ];
      })
      # Shell Integration
      (
        mkIf shellIntegrationEnabled {
          programs = {
            bash = {
              initExtra = mkIf cfg.enableBashIntegration ''
                if [[ "$TERM" != "dumb" ]]; then
                    eval "$(${getExe cfg.finalPackage} setup --generate-auto-start bash)"
                fi
              '';
            };
            zsh = {
              initContent = mkIf cfg.enableZshIntegration (
                mkOrder 200 ''
                  if [[ "$TERM" != "dumb" ]]; then
                      eval "$(${getExe cfg.finalPackage} setup --generate-auto-start zsh)"
                  fi
                ''
              );
            };
          };

          home = {
            sessionVariables = {
              ZELLIJ_AUTO_ATTACH = boolToString cfg.attachExistingSession;
              ZELLIJ_AUTO_EXIT = boolToString cfg.exitShellOnExit;
            };
          };
        }
      )
    ]);
}
