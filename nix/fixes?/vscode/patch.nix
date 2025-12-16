_: super: {
  vscode-extensions =
    super.vscode-extensions
    // {
      beancount = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "beancount-lsp-client";
        version = "0.0.138";
        publisher = "fengkx";
        hash = "sha256-ZToU5YTR4FGLa02ZD7KQH+eiMleGOAq/ycNW6o7GxGM=";
      };

      clangd = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "vscode-clangd";
        version = "0.3.2";
        publisher = "llvm-vs-code-extensions";
        hash = "sha256-17K2mVVe0XrZ2AGme4kq5NyFTAh1MrLw3nT1TkFOfus=";
      };

      cmake = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "cmake-tools";
        version = "1.22.21";
        publisher = "ms-vscode";
        hash = "sha256-Q4+5N3q06p2ZzhF4h2DLz80aUZiUPI4fdk7IUJZrn7Y=";
      };

      colors = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "color-info";
        version = "0.7.2";
        publisher = "bierner";
        hash = "sha256-Bf0thdt4yxH7OsRhIXeqvaxD1tbHTrUc4QJcju7Hv90=";
      };

      copilot = {
        completions = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot";
          version = "1.376.1794";
          publisher = "github";
          hash = "sha256-PZIxhDFFTARM25LDjg+Y3n0+oHMDKkvWjh4QNxy6CHc=";
        };
        chat = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "copilot-chat";
          version = "0.33.0";
          publisher = "github";
          hash = "sha256-Tx8qaO8/g1GaqK3CY1cM0bOJT1YcPL6+b1odmKquyTg=";
        };
      };

      lldb = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "lldb-dap";
        version = "0.3.20251028";
        publisher = "llvm-vs-code-extensions";
        hash = "sha256-GZvP/F1triajONiWPF6aLMRq/tnn9nVjXina++KiLQw=";
      };

      doxygen = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "doxdocgen";
        version = "1.4.0";
        publisher = "cschlosser";
        hash = "sha256-InEfF1X7AgtsV47h8WWq5DZh6k/wxYhl2r/pLZz9JbU=";
      };

      excalidraw = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "excalidraw-editor";
        version = "3.9.0";
        publisher = "pomdtr";
        hash = "sha256-DTmlHiMKnRUOEY8lsPe7JLASEAXmfqfUJdBkV0t08c0=";
      };

      go =
        super.vscode-utils.extensionFromVscodeMarketplace
        {
          name = "go";
          version = "0.51.1";
          publisher = "golang";
          hash = "sha256-8p5/FWkXnAC+C7ZVFTrWxNXGWyYJXitmSTi0Ui/81AQ=";
        };

      graphviz =
        super.vscode-utils.extensionFromVscodeMarketplace
        {
          name = "graphviz-interactive-preview";
          version = "0.3.5";
          publisher = "tintinweb";
          hash = "sha256-5A+RXGGVF/LY2IQ9jDvmS2/G6/T9BBqDPIx+7SXNeTo=";
        };

      python = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "python";
        version = "2025.16.0";
        publisher = "ms-python";
        hash = "sha256-dSDcfC9jxbewSY81fRBuS2LzSv7EsarZZOfx9OWkjnQ=";
      };

      jupyter = {
        notebook = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "jupyter";
          version = "2025.8.0";
          publisher = "ms-toolsai";
          hash = "sha256-MZHsgFxrAbDjRn0cH+cBolVvFQXlZPiVSZDUWDU6/jA=";
        };
        renderers = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "jupyter-renderers";
          version = "1.3.0";
          publisher = "ms-toolsai";
          hash = "sha256-GBqHvXikCgLGW7Xm05Iq1xqs8j9H9k9c8iASsAjA87I=";
        };
      };

      quarto = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "quarto";
        version = "1.126.0";
        publisher = "quarto";
        hash = "sha256-tt/rMTf6chRRLfrsJytUFPvlcgcUE7/7GvPxyZVyvbA=";
      };

      markdown = {
        footnotes = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "markdown-footnotes";
          version = "0.1.1";
          publisher = "bierner";
          hash = "sha256-h/Iyk8CKFr0M5ULXbEbjFsqplnlN7F+ZvnUTy1An5t4=";
        };
        charts = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "markdown-mermaid";
          version = "1.29.0";
          publisher = "bierner";
          hash = "sha256-qjfZ2/otO2BAIbhjqicHI2H0KKdpji55K+2XfOrzUIw=";
        };
      };

      nix = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "nix-ide";
        version = "0.5.0";
        publisher = "jnoortheen";
        hash = "sha256-jVuGQzMspbMojYq+af5fmuiaS3l3moG8L8Kyf40vots=";
      };

      open-in-external-app = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "open-in-external-app";
        version = "0.11.2";
        publisher = "YuTengjing";
        hash = "sha256-8CZ1qrBSRXYNDxUfHX3A+BmVXWZ3M6yrm1pns8iuyCM=";
      };

      paths = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "path-intellisense";
        version = "2.8.0";
        publisher = "christian-kohler";
        hash = "sha256-VPzy9o0DeYRkNwTGphC51vzBTNgQwqKg+t7MpGPLahM=";
      };

      spelling = {
        en = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "code-spell-checker";
          version = "4.2.6";
          publisher = "streetsidesoftware";
          hash = "sha256-veP2G/5vcaimjd98ur6Mhl4x1NKuvS21oO+HFJLHN+I=";
        };

        de = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "code-spell-checker-german";
          version = "2.3.4";
          publisher = "streetsidesoftware";
          hash = "sha256-zc0cv4AOswvYcC4xJOq2JEPMQ5qTj9Dad5HhxtNETEs=";
        };

        gb = super.vscode-utils.extensionFromVscodeMarketplace {
          name = "code-spell-checker-british-english";
          version = "1.4.33";
          publisher = "streetsidesoftware";
          hash = "sha256-eSc8rJgsbwHosz48S4FSXFJdpyKp1ttGMeOrNOUAXys=";
        };
      };

      uml = super.vscode-utils.extensionFromVscodeMarketplace {
        name = "plantuml";
        version = "2.18.1";
        publisher = "jebbs";
        hash = "sha256-o4FN/vUEK53ZLz5vAniUcnKDjWaKKH0oPZMbXVarDng=";
      };
    };
}
