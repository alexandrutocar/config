_: {
  wayland.windowManager.river.settings = {
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: This mode is useful for testing a nested wayland compositor.
    # ────────────────────────────────────────────────────────────────────────
    declare-mode = "passthrough";

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: This mode has only a single mapping to return to normal mode.
    # ────────────────────────────────────────────────────────────────────────
    map = {
      normal."Super F11" = "enter-mode passthrough";
      passthrough."Super F11" = "enter-mode normal";
    };
  };
}
