{pkgs, ...}: {
  home.packages = with pkgs; [
    stellarium
  ];
}
