_: {
  # GTK
  # ---
  gtk = let
    extraCss = ''
      headerbar.default-decoration {
        margin-bottom: 50px;
        margin-top: -100px;
      }
    '';
    extraConfig = {
      gtk-dialogs-use-header = false;
    };
  in {
    enable = true;
    colorScheme = "dark";

    gtk3 = {
      inherit extraCss extraConfig;
    };
    gtk4 = {
      inherit extraCss extraConfig;
    };
  };

  qt = {
    enable = true;
    style.name = "adwaita-dark";
  };

  # DEFAULT
  # -------
  xdg.mimeApps.defaultApplications = {
  };
}
