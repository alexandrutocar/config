{pkgs, ...}: {
  home.packages = with pkgs; [
    # LARGE LANGUAGE MODEL
    # --------------------
    custom.tlm

    # COMMUNICATION
    # -------------
    signal-desktop
  ];
}
