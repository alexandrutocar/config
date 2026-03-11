{pkgs, ...}: {
  home.packages = with pkgs; [
    # Astronomy
    stellarium

    # Cards
    anki
  ];
}
