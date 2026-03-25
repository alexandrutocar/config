# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀█ █▀█ █▀▀ ▄▀█ █▀█ ▄▀█ █▄░█ █▀▀ █▀▀
# █▀█ █▀▀ █▀▀ ██▄ █▀█ █▀▄ █▀█ █░▀█ █▄▄ ██▄
#
# language, time, fonts...
#
# ────────────────────────────────────────────────────────────────────────
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
in {
  imports = singleton (self + /etc/shared/settings/appearance.nix);

  # MULTILINGUAL INPUT
  # ------------------
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      addons = with (pkgs // pkgs.kdePackages); [
        # fcitx5-black-simplicity
        fcitx5-chinese-addons
        fcitx5-table-other
      ];
    };
  };

  # TILING COMPOSITOR
  # -----------------
  programs.river-classic = {
    enable = true;
  };

  # MOUSE AND TOUCHPAD
  # -------------------
  services.libinput = {
    enable = true;
  };

  # LOGIN MANAGER
  # -------------
  # ────────────────────────────────────────────────────────────────────────
  # TODO: Replace with `ly`.
  # - Investigate why it is generally not recommended to use `ly`.
  # ────────────────────────────────────────────────────────────────────────
  services.greetd = let
    river = pkgs.makeDesktopItem {
      desktopName = "river";
      comment = "dynamic tiling compositor";
      name = "river";
      exec = "${getExe pkgs.uwsm} start -F -N river -C \"dynamic tiling compositor\" ${getExe pkgs.river}";
      destination = "/share/wayland-session";
    };
  in {
    enable = true;
    settings = {
      default_session = {
        command = "${getExe pkgs.tuigreet} ${
          builtins.concatStringsSep " " [
            "--power-shutdown 'systemctl suspend'"
            "--power-reboot 'systemctl reboot'"
            "--power-no-setsid"

            "--sessions ${river}/share/wayland-session"

            "--theme 'time=white;button=white;input=white'"
            "--time"
          ]
        }";
      };
    };
  };
}
