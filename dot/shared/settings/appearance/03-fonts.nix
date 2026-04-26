{pkgs, ...}: {
  home.packages = with pkgs; [
    zpix
    # creep
    tamsyn
    cozette
  ];

  fonts = {
    fontconfig = {
      enable = true;
    };
  };
}
