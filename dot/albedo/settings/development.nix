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
}: {
  # VISUAL STUDIO CODE
  # ------------------
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium.fhsWithPackages (pkgs:
      with pkgs; [
        openssl.dev
        rustup
        zlib
        pkg-config
      ]);
  };

  # HELIX
  # -----
  programs.helix = {
    enable = true;

    settings = {
      theme = "default";

      keys = {
        normal = {
          "C-y" = [
            '':sh rm -f /tmp/unique-file''
            '':insert-output yazi "%{buffer_name}" --chooser-file=/tmp/unique-file''
            '':sh printf "\x1b[?1049h\x1b[?2004h" > /dev/tty''
            '':open %sh{cat /tmp/unique-file}''
            '':redraw''
          ];
        };
      };

      editor = {
        # Lines
        line-number = "relative";
        gutters = ["diagnostics" "line-numbers" "spacer" "diff"];

        # Cursor
        color-modes = true;
        cursorline = true;
        cursorcolumn = false;

        # Mouse Support
        mouse = true;
        middle-click-paste = true;

        # Scrolling Behavior
        scrolloff = 8; # Keep 8 lines visible above/below cursor
        scroll-lines = 3;

        # Text Rendering
        true-color = true;
        rulers = [80 120]; # Vertical rulers at 80 and 120 columns

        soft-wrap = {
          enable = true;
          max-wrap = 120;
          max-indent-retain = 40;
        };

        whitespace = {
          render = {
            nbsp = "all";
            newline = "none";
            space = "none";
            tab = "all";
          };
          characters = {
            space = "·";
            nbsp = "⍽";
            tab = "→";
            tabpad = "·";
          };
        };

        indent-guides = {
          render = true;
          character = "│";
          skip-levels = 1;
        };

        auto-save = {
          focus-lost = true;
          after-delay.enable = false;
        };

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        # Completion
        completion-trigger-len = 2;
        completion-replace = true;
        auto-completion = true;
        idle-timeout = 200;

        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
          "\"" = "\"";
          "'" = "'";
          "`" = "`";
          "<" = ">"; # Useful for HTML/JSX
        };

        statusline = {
          left = ["mode" "spinner" "version-control" "file-name" "read-only-indicator" "file-modification-indicator"];
          center = ["diagnostics" "selections"];
          right = ["position" "position-percentage" "total-line-numbers" "file-encoding"];
          separator = "│";
          mode = {
            normal = "NORMAL";
            insert = "INSERT";
            select = "SELECT";
          };
        };

        lsp = {
          display-messages = true;
          auto-signature-help = true;
          display-inlay-hints = true;
          display-signature-help-docs = true;
          snippets = true;
          goto-reference-include-declaration = true;
        };

        file-picker = {
          hidden = false;
          follow-symlinks = true;
          git-ignore = true;
          git-global = true;
          git-exclude = true;
        };

        search = {
          smart-case = true;
          wrap-around = true;
        };

        bufferline = "multiple";
        text-width = 120;

        auto-format = true;
        auto-info = true;
      };
    };

    languages.language = let
      lldb = {
        debugger = {
          command = "lldb-vscode";
          name = "lldb";
          transport = "stdio";
          templates = [
            {
              name = "binary";
              request = "launch";
              completion = [
                {
                  name = "binary";
                  completion = "filename";
                }
              ];
              args = {
                program = "{0}";
              };
            }
          ];
        };
      };
    in [
      # C/C++
      {
        name = "c";
        auto-format = true;
        inherit (lldb) debugger;
        language-servers = ["clangd"];
      }
      {
        name = "cpp";
        auto-format = true;
        inherit (lldb) debugger;
        language-servers = ["clangd"];
      }

      # Nix
      {
        name = "nix";
        auto-format = true;
        language-servers = ["nixd"];
      }

      # Typescript
      {
        name = "typescript";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "prettier";
          args = ["--parser" "typescript"];
        };
        language-servers = ["typescript-language-server" "eslint"];
        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
          "\"" = "\"";
          "'" = "'";
          "`" = "`";
          "<" = ">";
        };
      }

      # JavaScript
      {
        name = "javascript";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "prettier";
          args = ["--parser" "babel"];
        };
        language-servers = ["typescript-language-server" "eslint"];
        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
          "\"" = "\"";
          "'" = "'";
          "`" = "`";
          "<" = ">";
        };
      }

      # TSX
      {
        name = "tsx";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "prettier";
          args = ["--parser" "typescript"];
        };
        language-servers = ["typescript-language-server" "eslint"];
        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
          "\"" = "\"";
          "'" = "'";
          "`" = "`";
          "<" = ">";
        };
      }

      # JSX
      {
        name = "jsx";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "prettier";
          args = ["--parser" "babel"];
        };
        language-servers = ["typescript-language-server" "eslint"];
        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
          "\"" = "\"";
          "'" = "'";
          "`" = "`";
          "<" = ">";
        };
      }

      # HTML
      {
        name = "html";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "prettier";
          args = ["--parser" "html"];
        };
        language-servers = ["vscode-html-language-server"];
        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
          "\"" = "\"";
          "'" = "'";
          "`" = "`";
          "<" = ">";
        };
      }

      # CSS
      {
        name = "css";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "prettier";
          args = ["--parser" "css"];
        };
        language-servers = ["vscode-css-language-server"];
      }

      # Rust
      {
        name = "rust";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        language-servers = ["rust-analyzer"];
      }

      # Go
      {
        name = "go";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "goimports";
        };
        language-servers = ["gopls"];
      }

      # Lua
      {
        name = "lua";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        language-servers = ["lua-language-server"];
      }

      # Bash
      {
        name = "bash";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "shfmt";
          args = ["-i" "2"];
        };
        language-servers = ["bash-language-server"];
      }

      # JSON (optimized for large files)
      {
        name = "json";
        indent = {
          tab-width = 2;
          unit = "  ";
        };
        auto-format = true;
        formatter = {
          command = "prettier";
          args = ["--parser" "json"];
        };
        language-servers = ["vscode-json-language-server"];
      }
    ];

    languages.language-servers = {
      # C/C++
      clangd = {
        command = "clangd";
        args = [
          "--background-index"
          "--clang-tidy"
          "--completion-style=detailed"
          "--header-insertion=never"
        ];
      };

      # Nix
      nil = {
        command = "nixd";
        config.nixd.formatting.command = ["alejandra"];
      };

      # TypeScript/JavaScript
      typescript-language-server = {
        command = "typescript-language-server";
        args = ["--stdio"];
        config = {
          hostInfo = "helix";
          preferences = {
            includeInlayParameterNameHints = "all";
            includeInlayFunctionParameterTypeHints = true;
            includeInlayVariableTypeHints = true;
            includeInlayPropertyDeclarationTypeHints = true;
          };
        };
      };

      # ESLint
      eslint = {
        command = "vscode-eslint-language-server";
        args = ["--stdio"];
        config = {
          validate = "on";
          run = "onType";
          codeAction = {
            disableRuleComment = {
              enable = true;
              location = "separateLine";
            };
            showDocumentation.enable = true;
          };
          workingDirectory.mode = "auto";
        };
      };

      # Rust - rust-analyzer
      rust-analyzer = {
        command = "rust-analyzer";
        config = {
          check.command = "clippy";
          cargo.features = "all";
          inlayHints = {
            bindingModeHints.enable = true;
            closingBraceHints.minLines = 10;
            closureReturnTypeHints.enable = "with_block";
            discriminantHints.enable = "fieldless";
            lifetimeElisionHints.enable = "skip_trivial";
            typeHints.hideClosureInitialization = false;
          };
        };
      };

      # Go - gopls
      gopls = {
        command = "gopls";
        config = {
          hints = {
            assignVariableTypes = true;
            compositeLiteralFields = true;
            compositeLiteralTypes = true;
            constantValues = true;
            functionTypeParameters = true;
            parameterNames = true;
            rangeVariableTypes = true;
          };
        };
      };

      # Lua - lua-language-server
      lua-language-server = {
        command = "lua-language-server";
      };

      # Bash - bash-language-server
      bash-language-server = {
        command = "bash-language-server";
        args = ["start"];
      };

      # HTML/CSS - vscode-langservers
      vscode-html-language-server = {
        command = "vscode-html-language-server";
        args = ["--stdio"];
      };

      vscode-css-language-server = {
        command = "vscode-css-language-server";
        args = ["--stdio"];
      };

      # JSON language server (great for large JSON files)
      vscode-json-language-server = {
        command = "vscode-json-language-server";
        args = ["--stdio"];
        config = {
          provideFormatter = true;
          json.validate.enable = true;
        };
      };
    };
  };

  # SSH AGENT
  # ---------
  services.ssh-agent = {
    enable = true;
  };
}
