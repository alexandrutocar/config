{pkgs, ...}: {
  home.packages = with pkgs; [
    # OFFICE DOCUMENT EDITORS
    # -----------------------

    libreoffice

    # AUDIO EDITORS
    # -------------

    audacity

    # TERMINAL MULTIPLEXER
    # -------- -----------
    zellij
  ];

  # CODE/TEXT EDITORS
  # -----------------
  programs = {
    # [VIM](https://github.com/vim/vim)
    vim = {
      enable = true;
    };

    # [CODIUM](https://github.com/vscodium/vscodium)
    vscode = {
      enable = true;
      package = pkgs.vscodium;
    };
  };
}
