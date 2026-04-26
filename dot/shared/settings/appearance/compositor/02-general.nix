{lib, ...}: {
  wayland.windowManager.river = let
    inherit (lib.extra.colors) hexToBin;
  in {
    enable = true;

    settings = {
      background-color = hexToBin "#000000";

      border-color-focused = hexToBin "#93a1a1";
      border-color-unfocused = hexToBin "#586e75";

      keyboard-layout = "'de'";

      set-repeat = "50 300";
    };
  };
}
