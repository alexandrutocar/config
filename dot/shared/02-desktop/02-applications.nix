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
      gtk-application-prefer-dark-theme = true;
      gtk-dialogs-use-header = false;
    };
  in {
    enable = true;

    gtk3 = {
      inherit extraCss extraConfig;
    };
    gtk4 = {
      inherit extraCss extraConfig;
      theme = null;
    };
  };

  # DEFAULT
  # -------
  xdg.mimeApps.defaultApplications = {
  };
}
