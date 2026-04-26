{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.meta) getExe getExe';
in {
  wayland.windowManager.river.extraConfig = ''
    # start the default layout generator.
    # river will send the process group of the init executable SIGTERM on exit.
    ${getExe pkgs.rivercarro} -inner-gaps 6 -outer-gaps 6 &

    # start input method
    fcitx5 -d &
    fcitx5-remote -r &

    # systemd activation environment
    ${getExe' pkgs.dbus "dbus-update-activation-environment"} --systemd \
        DISPLAY \
        XDG_CURRENT_DESKTOP \
        WAYLAND_DISPLAY \
        NIXOS_OZONE_WL \
        XCURSOR_THEME \
        XCURSOR_SIZE

    # systemd river-session.target
    ${getExe' pkgs.systemd "systemctl"} --user stop river-session.target
    ${getExe' pkgs.systemd "systemctl"} --user start river-session.target
  '';
}
