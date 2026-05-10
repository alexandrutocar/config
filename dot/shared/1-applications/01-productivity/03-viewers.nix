{pkgs, ...}: {
  home.packages = with pkgs; [
    feh # photo
    mpv # image/video/audio
  ];
}
