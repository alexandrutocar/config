# ────────────────────────────────────────────────────────────────────────
#
# █▄▄ █▀█ █▀█ █░█░█ █▀ █▀▀ █▀█
# █▄█ █▀▄ █▄█ ▀▄▀▄▀ ▄█ ██▄ █▀▄
#
# firefox, profiles, search engines, privacy, extensions...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  programs = {
    # INTERNET
    # --------
    firefox = {
      enable = true;

      # programs.firefox.configPath = "${config.xdg.configHome}/mozilla/firefox";
      configPath = ".mozilla/firefox";

      profiles = {
        personal = {
          name = "Personal";

          id = 0;
          isDefault = true;

          settings = {
            "browser.startup.page" = 3; # Start from where it has been left off.
            "browser.tabs.drawInTitlebar" = true;
            "svg.context-properties.content.enabled" = true;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

            "signon.rememberSignons" = false;
            "widget.use-xdg-desktop-portal.file-picker" = 1;
            "browser.aboutConfig.showWarning" = false;
            "browser.compactmode.show" = true;
            "browser.taskbarTabs.enabled" = true;

            "browser.cache.disk.enable" = false; # Be kind to hard drive

            # Firefox 75+ remembers the last workspace it was opened on as part of its session management.
            # This is annoying, because I can have a blank workspace, click Firefox from the launcher, and
            # then have Firefox open on some other workspace.
            "widget.disable-workspace-management" = true;
          };
        };
      };
    };
  };

  wayland.windowManager.river.settings = {
    rule-add = {
      "-app-id"."'firefox'"."-title" = {
        "'*'" = "tags 2";
        "'Extension: *'" = "float";
      };
    };
  };
}
