# ────────────────────────────────────────────────────────────────────────
#
# █▀ █░█ █▀▀ █░░ █░░
# ▄█ █▀█ ██▄ █▄▄ █▄▄
#
# shell, privacy guard, terminal, utilities ...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.meta) getExe;
in {
  # USER'S SHELL
  # ------------
  users.defaultUserShell = pkgs.zsh;

  programs = {
    # BAT
    # ---
    bat = {
      enable = true;

      scripts = with pkgs.bat-extras; [
        batdiff
        batgrep
      ];

      settings = {
        paging = "never";
        theme = "ansi";
      };
    };

    # GIT
    # ---
    git = {
      enable = true;
      config = {
        alias = {
          st = "status -sb";
          co = "checkout";
          br = "branch";
          lg = "log --oneline --graph --decorate --all";
        };

        init.defaultBranch = "main";

        color = {
          ui = "auto";
          branch = "auto";
          diff = "auto";
          status = "auto";
        };

        commit.gpgSign = true;

        gc.auto = 256;

        gpg.program = "${getExe pkgs.gnupg}";

        core = {
          editor = "${getExe config.programs.vim.package}";
          pager = "less -FRX";
          whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
        };

        credentials.helper = "cache";

        log.showSignature = true;

        merge.verifySignatures = true;

        pager.log = "less --pager=quit-if-one-screen";

        protocol.version = 2;

        tag.gpgSign = true;

        transfer.credentialsInUrl = "die";

        http.sslVerify = true;

        http.followRedirects = false;

        url = {
          "git@github.com:" = {
            insteadOf = [
              "gh:"
              "github:"
            ];
          };

          "git@codeberg.org:" = {
            insteadOf = [
              "cb:"
              "codeberg:"
            ];
          };

          "git@git.sr.ht:" = {
            insteadOf = [
              "srht:"
              "sourcehut:"
            ];
          };
        };
      };
    };

    # PAY-RESPECTS
    # ------------
    pay-respects = {
      enable = true;
    };

    # TMUX
    # ----
    tmux = {
      enable = true;

      plugins = with pkgs.tmuxPlugins; [
        # session autosave
        resurrect
        continuum

        # keybindings
        sensible
      ];

      extraConfig = ''
        # set prefix key
        unbind C-a
        set-option -g prefix C-a
        bind-key C-a send-prefix

        # improve color support
        set -g default-terminal "screen-256color"

        # set a more readable and attractive status bar
        set -g status-bg colour234
        set -g status-fg white

        # left side of the status bar
        set -g status-left-length 100
        set -g status-left "#[fg=green]#S #[fg=yellow]| #[fg=cyan]#(whoami) #[fg=yellow]| #[fg=blue]%a #[fg=cyan]%Y-%m-%d #[fg=magenta]%H:%M:%S #[fg=yellow]|"

        # right side of the status bar
        set -g status-right-length 100
        set -g status-right "#[fg=yellow]| #[fg=cyan]#(cut -c -1 /sys/class/power_supply/BAT0/status)#[fg=red]#(cat /sys/class/power_supply/BAT0/capacity)% #[fg=yellow]| #[fg=green]#(cat /proc/loadavg | cut -d ' ' -f 1,2,3) #[fg=yellow]| #[fg=magenta]#(ifstat -i eth0 -q 1 1 | awk 'NR==3 {print $1,$2}')"

        # pane border and status
        set -g pane-border-style fg=colour235
        set -g pane-active-border-style fg=colour40
        setw -g window-status-style fg=colour244
        setw -g window-status-current-style fg=colour51,bold

        # customize window titles
        setw -g window-status-format " #I:#W#F "
        setw -g window-status-current-format " #I:#W#F "

        # mouse support
        set -g mouse on

        # other sensible settings
        set -g history-limit 10000
        set -s escape-time 0

        # clipboard behavior
        set -s copy-command 'wl-copy'

        # autosave tmux session
        set -g @continuum-restore 'on'
      '';
    };

    # VIM
    # ---
    vim = {
      enable = true;
    };

    # YAZI
    # ----
    yazi = {
      enable = true;
      plugins = {
        inherit
          (pkgs.yaziPlugins)
          chmod
          diff
          git
          mount
          piper
          smart-enter
          smart-paste
          smart-filter
          jump-to-char
          bypass
          starship
          restore
          time-travel
          ;
      };
      settings = {
        yazi = {};
        theme = {};
        keymap = {
          manager.prepend_keymap = [
            {
              on = "T";
              run = ''shell --orphan --confirm "$TERM ."'';
              desc = "Open new terminal at current directory";
            }
          ];
        };
      };
    };

    # ZOXIDE
    # ------
    zoxide.enable = true;

    # ZSH
    # ---
    zsh = {
      enable = true;

      autosuggestions.enable = true;
      interactiveShellInit = ''
        HISTFILE=~/.zsh_history
        HISTSIZE=100000
        SAVEHIST=100000

        export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh

        ZSH_THEME="robbyrussell";

        plugins=(
          colored-man-pages
          fancy-ctrl-z
          branch
          git
          sudo
          zoxide
          systemadmin
        )

        source $ZSH/oh-my-zsh.sh
      '';

      syntaxHighlighting.enable = true;
    };
  };

  # STANDARD UTILITIES
  # ------------------
  environment.systemPackages = with pkgs; [
    # System Monitoring
    btop # modern, feature-rich, interactive monitoring
    lsof # standard for listing open files

    # Disk & Filesystem
    ncdu # efficient disk usage analyzer
    parted # disk partitioning
    gptfdisk # comfortable disk partitioning
    rclone # cloud storage sync
    restic # backup tool
    rsync # file synchronization
    glib # virtual filesystems

    # Version Control
    git-annex

    # Databases
    sqlitebrowser

    # Encryption & Keys
    openssl
    gnupg
    age
    yubikey-manager

    # Key Management
    cfssl

    # Nix
    nix-tree
    nix-diff
    nvd

    # Networking
    curl # HTTP client
    dig # DNS lookup

    # Archiving & Compression
    pigz # parallel gzip compression
    xz # compression
    zip # archiving
    zstd # modern compression
    unzip # extraction

    # Scripting
    gnused # stream editor
    bc # basic calculator

    # Text
    jq # JSON processor
    yq # XML, YAML processor
    xq-xml # XML (XPath) query utility

    # Hardware & Kernel
    hwinfo # hardware detection
    inxi # system information
    iw # wireless interfaces

    # Peripheral & Bus Info
    pciutils # PCI device info
    usbutils # USB device info
  ];
}
