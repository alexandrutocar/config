{pkgs, ...}: {
  home.packages = with pkgs; [
    tamsyn
  ];

  fonts = {
    fontconfig = {
      enable = true;
    };
  };
}
