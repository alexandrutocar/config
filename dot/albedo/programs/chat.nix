{pkgs, ...}: {
  home.packages = with pkgs; [
    # LANGUAGE MODEL INTERFACE
    # ------------------------
    custom.tlm

    # PERSONAL COMMUNICATION
    # ----------------------
    signal-desktop
  ];
}
