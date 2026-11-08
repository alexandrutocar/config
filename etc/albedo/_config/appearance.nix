{
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
in {
  imports = singleton (self + "/etc/shared/01-settings/appearance.nix");

  # SYSTEM TIME
  # -----------
  time.timeZone = "Europe/Berlin";

  # SYSTEM LOCALE
  # -------------
  i18n = {
    defaultLocale = "de_DE.UTF-8";
    extraLocales = [
      # International
      "en_US.UTF-8/UTF-8"
      # East-Europe
      "ru_RU.UTF-8/UTF-8"
      "uk_UA.UTF-8/UTF-8"
      # East-Asia
      "zh_CN.UTF-8/UTF-8"
      "zh_SG.UTF-8/UTF-8"
      "zh_TW.UTF-8/UTF-8"
    ];

    # MULTILINGUAL INPUT
    # ------------------
    inputMethod = {
      enable = true;
      type = "fcitx5";

      fcitx5 = {
        addons = with (pkgs // pkgs.kdePackages); [
          fcitx5-black-simplicity
          fcitx5-chinese-addons
          fcitx5-table-other
        ];
      };
    };
  };

  # TILING COMPOSITOR
  # -----------------
  programs.river = {
    enable = true;
  };

  # DEFAULT XDP
  # -----------
  xdg.portal = {
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];

    config = {
      common = {
        default = ["gtk"];
      };
    };
  };

  # XDPW (xdg-desktop-portal-wlr)
  # -----------------------------
  xdg.portal.wlr = {
    enable = true;
    settings = {
      screencast = {
        chooser_type = "dmenu";
        chooser_cmd = "${pkgs.tofi}/bin/tofi";
      };
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # LOGIN MANAGER
  # -------------
  services.greetd = let
    river = pkgs.makeDesktopItem {
      desktopName = "river";
      comment = "dynamic tiling compositor";
      name = "river";
      exec = "${getExe pkgs.uwsm} start -F -N river -C \"dynamic tiling compositor\" ${getExe config.programs.river.package}";
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
