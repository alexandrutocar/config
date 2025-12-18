# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █▀▀ █░█ █▀▀ █░░ █▀█ █▀█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# █▄▀ ██▄ ▀▄▀ ██▄ █▄▄ █▄█ █▀▀ █░▀░█ ██▄ █░▀█ ░█░
#
# development, programming, writing, tools, extensions...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: let
  mkProfile = let
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkMerge;
  in
    {
      extensions ? [],
      settings ? {},
      sharedSettings ? (mkMerge [
        {
          # Files
          "files.autoSave" = "afterDelay";
          "files.exclude" = {
            "_build" = true;
            ".elixir_ls" = true;
            "**/.classpath" = true;
            "**/.factorypath" = true;
            "**/.project" = true;
            "**/.settings" = true;
            "deps" = true;
            "node_modules" = false;
            "vendor" = true;
          };
          "files.insertFinalNewline" = true;
          "files.restoreUndoStack" = false;
          "files.trimFinalNewlines" = true;
          "files.trimTrailingWhitespace" = true;

          # Font
          # ────────────────────────────────────────────────────────────────────────
          # TODO: Look into custom editor fonts.
          # ────────────────────────────────────────────────────────────────────────
          # "editor.fontFamily" = "Tamsyn, monospace";
          # "editor.fontLigatures" = false;

          # Formatting
          "editor.formatOnSave" = true;

          # WORKBENCH
          # ---------

          "workbench.secondarySideBar.defaultVisibility" = "hidden";

          # Zen Mode

          "zenMode.hideActivityBar" = false;

          # WINDOW
          # ------

          "window.density.editorTabHeight" = "compact";

          # FEATURES
          # --------

          # Explorer

          "explorer.confirmDelete" = false;
          "explorer.incrementalNaming" = "smart";
          "explorer.openEditors.sortOrder" = "alphabetical";

          "explorer.fileNesting.enabled" = true;
          "explorer.fileNesting.expand" = false;
          "explorer.fileNesting.patterns" = {
            ".env" = ".env.*";
            ".env.*" = ".env.\${capture}.local";
            "*.ex" = "\${capture}.eex, \${capture}.html.heex";
            "*.go" = "\${capture}_test.go";
            "*.js" = "\${capture}.d.ts, \${capture}.d.ts.map, \${capture}.js.map, \${capture}.min.js, \${capture}.test.d.ts.map, \${capture}.test.js";
            "*.mjs" = "\${capture}.d.mts, \${capture}.d.mts.map, \${capture}.mjs.map";
            "*.mts" = "\${capture}.d.mts, \${capture}.d.mts.map, \${capture}.mjs, \${capture}.mjs.map";
            "*.svelte" = "\${capture}.css, \${capture}.stories.js, \${capture}.stories.ts, \${capture}.svelte.d.ts, \${capture}.svelte.d.ts.map, \${capture}.test.ts";
            "*.ts" = "\${capture}.test.ts, \${capture}.test-d.ts, \${capture}.test.ts.map, \${capture}.js";
            "compose.yaml" = "compose.override.yaml, *.compose.yaml, *.compose.override.yaml";
            "minepkg.toml" = ".minepkg-lock.toml";
            "mix.exs" = "mix.lock";
            "package.json" = "bun.lockb, package-lock.json, pnpm-lock.yaml, yarn.lock";
            "flake.nix" = "flake.lock";
            "tailwind.config.cjs" = "tailwind.*.cjs, tailwind.*.json";
            "tsconfig.json" = "tsconfig.*.json, tsconfig.tsbuildinfo";
            "tsconfig.tsbuildinfo" = "tsconfig.*.tsbuildinfo";
          };

          # Extensions
          "extensions.autoRestart" = true;
          "extensions.autoUpdate" = false;

          # Terminal
          "terminal.external.linuxExec" = "${pkgs.foot}";
          "terminal.integrated.defaultProfile.linux" = "zsh";

          "terminal.integrated.enableMultiLinePasteWarning" = "always";
          "terminal.integrated.fontFamily" = "Tamsyn, monospace, MesloLGS NF, Noto Color Emoji";
          "terminal.integrated.hideOnStartup" = "whenEmpty";
          "terminal.integrated.minimumContrastRatio" = 4.5;
          "terminal.integrated.scrollback" = 8000;
          "terminal.integrated.showExitAlert" = false;
          "terminal.integrated.stickyScroll.enabled" = false;
          "terminal.integrated.suggest.enabled" = true;
          "terminal.integrated.tabs.focusMode" = "singleClick";
          "terminal.integrated.tabStopWidth" = 2;

          # APPLICATION
          # ---------

          # Telemetry
          "telemetry.telemetryLevel" = "off";

          "telemetry.editStats.details.enabled" = false;
          "telemetry.editStats.enabled" = false;
          "telemetry.editStats.showDecorations" = false;
          "telemetry.editStats.showStatusBar" = false;

          "telemetry.feedback.enabled" = false;

          # Settings Sync
          "settingsSync.keybindingsPerPlatform" = false;

          "update.mode" = "none";
          "extensions.autoCheckUpdates" = false;
          "workbench.enableExperiments" = false;
          "workbench.settings.enableNaturalLanguageSearch" = false;
          "applicationInsights.enabled" = false;
        }

        # Extension: Excalidraw
        {
          "excalidraw.theme" = "auto";
        }

        # Extension: Copilot
        {
          "github.copilot.enable"."*" = false;
          "github.copilot.inlineSuggest.enable" = false;
          "github.copilot.nextEditSuggestions.enabled" = false;
        }

        # Extension: Git
        {
          "git.enableSmartCommit" = true;
          "git.openRepositoryInParentFolders" = "never";
        }

        # Extension: GitHub
        {
          "github.gitProtocol" = "ssh";
        }

        # Extension: Spell Checker
        {
          "cSpell.enabled" = true;
          "cSpell.language" = "en,en-gb,de-de";
        }

        # Extension: Nix
        {
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "${getExe pkgs.nixd}";
          "nix.serverSettings" = {
            nixd = {
              formatting.command = [
                "${getExe pkgs.alejandra}"
              ];
            };
          };
        }

        # Extension: Open In External App
        {
          "openInExternalApp.openMapper" = [
            {
              "extensionName" = "pdf";
              "apps" = [
                {
                  title = "Zathura";
                  openCommand = getExe pkgs.zathura;
                }
                {
                  title = "Sioyek";
                  openCommand = getExe pkgs.sioyek;
                }
                {
                  title = "Firefox";
                  openCommand = getExe config.programs.firefox.finalPackage;
                }
              ];
            }
          ];
        }
      ]),
      sharedExtensions ? (with pkgs.vscode-extensions; [
        # Assistance Tools
        copilot.completions

        # Drawing
        excalidraw

        # Writing
        quarto

        # Intellisense
        paths

        # Flakes
        nix

        # YAML
        yaml

        # OAS
        openapi

        # Spelling
        spelling.en
        spelling.de
        spelling.gb

        # Utilities
        open-in-external-app
      ]),
    }: {
      extensions = sharedExtensions ++ extensions;
      userSettings = mkMerge [sharedSettings settings];
    };
in {
  # VISUAL STUDIO CODE
  # ------------------
  programs.vscode = {
    enable = true;

    package = pkgs.vscodium;

    profiles = {
      default = mkProfile {};

      clang = mkProfile {
        extensions = with pkgs.vscode-extensions; [
          doxygen
          clangd
          cmake
          lldb
        ];
      };

      go = mkProfile {
        extensions = with pkgs.vscode-extensions; [
          go
        ];
      };

      python = mkProfile {
        extensions = with pkgs.vscode-extensions; [
          python
        ];
      };

      jupyter = mkProfile {
        extensions = with pkgs.vscode-extensions; [
          jupyter.notebook
          jupyter.renderers
        ];
      };

      beancount = mkProfile {
        extensions = with pkgs.vscode-extensions; [
          beancount
        ];
      };
    };
  };

  # SSH AGENT
  # ---------
  services.ssh-agent = {
    enable = true;
  };
}
