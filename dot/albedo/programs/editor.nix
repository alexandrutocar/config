{pkgs, ...}: {
  home.packages = with pkgs; [
    # OFFICE DOCUMENT EDITORS
    # -----------------------

    libreoffice

    # GRAPHICS EDITORS
    # ----------------

    # Pictures
    gimp

    # Vector Graphics
    inkscape

    # AUDIO EDITORS
    # -------------

    audacity
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
