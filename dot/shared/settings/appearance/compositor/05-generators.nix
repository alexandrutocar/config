{
  pkgs,
  lib,
  ...
}: {
  wayland.windowManager.river.settings = let
    inherit (lib.strings) getName;

    generator = getName pkgs.rivercarro;
  in {
    default-layout = generator;

    map.normal = {
      # Super+H and Super+L to decrease/increase the main ratio of rivercarro(1)
      "Super H" = ''send-layout-cmd ${generator} "main-ratio -0.05"'';
      "Super L" = ''send-layout-cmd ${generator} "main-ratio +0.05"'';

      # Super+Shift+H and Super+Shift+L to increment/decrement the main count of rivercarro(1)
      "Super+Shift H" = ''send-layout-cmd ${generator} "main-count +1"'';
      "Super+Shift L" = ''send-layout-cmd ${generator} "main-count -1"'';

      # Super+{Up,Right,Down,Left} to change layout orientation
      "Super Up" = ''send-layout-cmd ${generator} "main-location top"'';
      "Super Right" = ''send-layout-cmd ${generator} "main-location right"'';
      "Super Down" = ''send-layout-cmd ${generator} "main-location bottom"'';
      "Super Left" = ''send-layout-cmd ${generator} "main-location left"'';
    };
  };
}
