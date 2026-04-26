{
  pkgs,
  lib,
  ...
}: {
  wayland.windowManager.river.settings = let
    inherit (lib.meta) getExe;

    inherit (pkgs.custom.scripts.desktop) launcher locker sshot;
  in {
    map.normal = {
      # Super+Super+S (Fn+F11) to take a screenshot.
      "Shift+Super S" = "spawn '${getExe sshot}'";

      # Super+Shift+Return to start an instance of foot (https://codeberg.org/dnkl/foot)
      "Super+Shift Return" = "spawn foot";

      # Super+A to run application launcher
      "Super A" = "spawn '${getExe launcher}'";

      # Super+Q to close the focused view
      "Super Q" = "close";

      # Super+S to lock the screen
      "Super S" = "spawn '${getExe locker}'";

      # Super+Shift+E to exit river
      "Super+Shift E" = "spawn 'uwsm stop'";
    };
  };
}
