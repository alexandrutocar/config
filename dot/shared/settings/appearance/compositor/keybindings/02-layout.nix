_: {
  wayland.windowManager.river.settings = {
    map-pointer.normal = {
      # Super + Middle Mouse Button to toggle float
      "Super BTN_MIDDLE" = "toggle-float";

      # Super + Left Mouse Button to move views
      "Super BTN_LEFT" = "move-view";

      # Super + Right Mouse Button to resize views
      "Super+Alt BTN_LEFT" = "resize-view";
    };

    map.normal = {
      # Super+J and Super+K to focus the next/previous view in the layout stack
      "Super J" = "focus-view next";
      "Super K" = "focus-view previous";

      # Super+Shift+J and Super+Shift+K to swap the focused view with the next/previous
      # view in the layout stack
      "Super+Shift J" = "swap next";
      "Super+Shift K" = "swap previous";

      # Super+Period and Super+Comma to focus the next/previous output
      "Super Period" = "focus-output next";
      "Super Comma" = "focus-output previous";

      # Super+Shift+{Period,Comma} to send the focused view to the next/previous output
      "Super+Shift Period" = "send-to-output next";
      "Super+Shift Comma" = "send-to-output previous";

      # Super+Return to bump the focused view to the top of the layout stack
      "Super Return" = "zoom";

      # Super+Alt+{H,J,K,L} to move views
      "Super+Alt H" = "move left 100";
      "Super+Alt J" = "move down 100";
      "Super+Alt K" = "move up 100";
      "Super+Alt L" = "move right 100";

      # Super+Alt+Control+{H,J,K,L} to snap views to screen edges
      "Super+Alt+Control H" = "snap left";
      "Super+Alt+Control J" = "snap down";
      "Super+Alt+Control K" = "snap up";
      "Super+Alt+Control L" = "snap right";

      # Super+Alt+Shift+{H,J,K,L} to resize views
      "Super+Alt+Shift H" = "resize horizontal -100";
      "Super+Alt+Shift J" = "resize vertical 100";
      "Super+Alt+Shift K" = "resize vertical -100";
      "Super+Alt+Shift L" = "resize horizontal 100";

      # Super+Space to toggle float
      "Super Space" = "toggle-float";

      # Super+F to toggle fullscreen
      "Super F" = "toggle-fullscreen";
    };
  };
}
