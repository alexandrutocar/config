{pkgs, ...}: {
  home.packages = with pkgs; [
    uwsm
  ];

  wayland.windowManager.river.systemd.enable = true;
}
