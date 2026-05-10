# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █▀▀ █▀ █▄▀ ▀█▀ █▀█ █▀█
# █▄▀ ██▄ ▄█ █░█ ░█░ █▄█ █▀▀
#
# █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# ██▄ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
#
# compositor, display, keybindings, notifications,
# wallpaper, scripts...
#
# ────────────────────────────────────────────────────────────────────────
{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # UNIVERSAL SESSION MANAGER
    # -------------------------
    uwsm
  ];

  # DYNAMIC TILING COMPOSITOR
  # -------------------------
  wayland.windowManager.river = let
    inherit (lib.extra.colors) hexToBin;
    inherit (lib.extra.math) pow seq;
    inherit (lib.attrsets) recursiveUpdate;
    inherit (lib.lists) foldl';
    inherit (lib.meta) getExe;
    inherit (lib.strings) getName;

    inherit (pkgs.custom.scripts.desktop) brightness launcher locker sshot tcam tmic volume;
    inherit (pkgs) playerctl rivercarro;
  in {
    enable = true;

    systemd.enable = true;

    settings = foldl' recursiveUpdate {} [
      # General Configuration
      {
        # set background
        background-color = hexToBin "#000000";

        # set border color
        border-color-focused = hexToBin "#93a1a1";
        border-color-unfocused = hexToBin "#586e75";

        # set the keyboard layout
        keyboard-layout = "'de'";

        # set keyboard repeat rate
        set-repeat = "50 300";

        # Declare a passthrough mode. This mode has only a single mapping to return to
        # normal mode. This makes it useful for testing a nested wayland compositor
        declare-mode = "passthrough";
      }

      # Keybindings
      # Various media key mapping examples for both normal and locked mode which do
      # not have a modifier
      (
        foldl' recursiveUpdate {} (
          map (
            mode: {
              map.${mode} = {
                # Eject the optical drive (well if you still have one that is)
                "None XF86Eject" = "spawn 'eject -T'";

                # Control pulse audio volume with pamixer (https://github.com/cdemoulins/pamixer)
                "None XF86AudioMute" = "spawn '${getExe volume} /'";
                "Super XF86AudioMute" = "spawn '${getExe volume} /'";

                # Control MPRIS aware media players with playerctl (https://github.com/altdesktop/playerctl)
                "None XF86AudioMedia" = "spawn '${getExe playerctl} play-pause'";
                "None XF86AudioPlay" = "spawn '${getExe playerctl} play-pause'";
                "None XF86AudioPrev" = "spawn '${getExe playerctl} previous'";
                "None XF86AudioNext" = "spawn '${getExe playerctl} next'";

                # Control keyboard toggles
                "None XF86WebCam" = "spawn '${getExe tcam}'";
                "Super XF86WebCam" = "spawn '${getExe tcam}'";
                "None XF86AudioMicMute" = "spawn '${getExe tmic}'";
                "Super XF86AudioMicMute" = "spawn '${getExe tmic}'";
              };

              map."-repeat".${mode} = {
                # Control pulse audio volume with pamixer (https://github.com/cdemoulins/pamixer)
                "None XF86AudioRaiseVolume" = "spawn '${getExe volume} +'";
                "None XF86AudioLowerVolume" = "spawn '${getExe volume} -'";
                "Super XF86AudioRaiseVolume" = "spawn '${getExe volume} +'";
                "Super XF86AudioLowerVolume" = "spawn '${getExe volume} -'";

                # Control screen backlight brightness with brightnessctl (https://github.com/Hummer12007/brightnessctl)
                "None XF86MonBrightnessUp" = "spawn '${getExe brightness} +'";
                "None XF86MonBrightnessDown" = "spawn '${getExe brightness} -'";
                "Super XF86MonBrightnessUp" = "spawn '${getExe brightness} +'";
                "Super XF86MonBrightnessDown" = "spawn '${getExe brightness} -'";
              };
            }
          ) ["locked" "normal"]
        )
      )
      {
        map.normal = {
          # Super+Super+S (Fn+F11) to take a screenshot.
          "Shift+Super S" = "spawn '${getExe sshot}'";
        };
      }
      {
        map.normal =
          {
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

            # Super+H and Super+L to decrease/increase the main ratio of rivercarro(1)
            "Super H" = "send-layout-cmd ${getName rivercarro} \"main-ratio -0.05\"";
            "Super L" = "send-layout-cmd ${getName rivercarro} \"main-ratio +0.05\"";

            # Super+Shift+H and Super+Shift+L to increment/decrement the main count of rivercarro(1)
            "Super+Shift H" = "send-layout-cmd ${getName rivercarro} \"main-count +1\"";
            "Super+Shift L" = "send-layout-cmd ${getName rivercarro} \"main-count -1\"";

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
          }
          // (
            foldl' recursiveUpdate {} (
              map (
                i: let
                  key = ''"${toString i}"'';
                  tag = toString (pow 2 (i - 1));
                in {
                  # # Super [1-9] to focus tag [0-8]
                  "Super ${key}" = "set-focused-tags ${tag}";

                  # Super+Shift [1-9] to tag focused view with tag [0-8]
                  "Super+Shift ${key}" = "set-view-tags ${tag}";

                  # Super+Control [1-9] to toggle focus of tag [0-8]
                  "Super+Control ${key}" = "toggle-focused-tags ${tag}";

                  # Super+Shift+Control [1-9] to toggle tag [0-8] of focused view
                  "Super+Shift+Control ${key}" = "toggle-view-tags ${tag}";
                }
              ) (seq 1 9)
            )
          )
          // (let
            tag = toString ((pow 2 32) - 1);
          in {
            # Super 0 to focus all tags
            "Super 0" = "set-focused-tags ${tag}";

            # Super+Shift 0 to tag focused view with all tags
            "Super+Shift 0" = "set-view-tags ${tag}";
          })
          // {
            # Super+Space to toggle float
            "Super Space" = "toggle-float";

            # Super+F to toggle fullscreen
            "Super F" = "toggle-fullscreen";

            # Super+{Up,Right,Down,Left} to change layout orientation
            "Super Up" = "send-layout-cmd ${getName rivercarro} \"main-location top\"";
            "Super Right" = "send-layout-cmd ${getName rivercarro} \"main-location right\"";
            "Super Down" = "send-layout-cmd ${getName rivercarro} \"main-location bottom\"";
            "Super Left" = "send-layout-cmd ${getName rivercarro} \"main-location left\"";
          }
          // {
            # Super+F11 to enter passthrough mode
            "Super F11" = "enter-mode passthrough";
          };

        map.passthrough = {
          # Super+F11 to return to normal mode
          "Super F11" = "enter-mode normal";
        };
      }

      # Layout
      {
        # set the default layout generator
        default-layout = "${getName rivercarro}";
      }

      # Mouse
      {
        map-pointer.normal = {
          # Super + Left Mouse Button to move views
          "Super BTN_LEFT" = "move-view";

          # Super + Right Mouse Button to resize views
          "Super+Alt BTN_LEFT" = "resize-view";

          # Super + Middle Mouse Button to toggle float
          "Super BTN_MIDDLE" = "toggle-float";
        };
      }

      # Touchpad
      {
        # configure touchpad
        input."pointer-1267-12736-ASUE120B:00_04F3:31C0_Touchpad" = {
          tap = "enabled";
          tap-button-map = "left-right-middle";
          natural-scroll = "enabled";
          scroll-factor = 0.7;
        };
      }

      # Rules
      {
        rule-add = {
          "-app-id"."'foot'"."-title"."'*'" = "float";
          "-app-id"."'foot'"."-title"."'Yazi: *'"."dimensions" = "750 500";
        };
      }
    ];

    extraConfig = ''
      # start the default layout generator.
      # river will send the process group of the init executable SIGTERM on exit.
      ${getExe pkgs.rivercarro} -inner-gaps 6 -outer-gaps 6 &

      # start input method
      fcitx5 -d &
      fcitx5-remote -r &

      # systemd activation environment
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
          DISPLAY \
          XDG_CURRENT_DESKTOP \
          WAYLAND_DISPLAY \
          NIXOS_OZONE_WL \
          XCURSOR_THEME \
          XCURSOR_SIZE

      # systemd river-session.target
      ${pkgs.systemd}/bin/systemctl --user stop river-session.target
      ${pkgs.systemd}/bin/systemctl --user start river-session.target
    '';
  };
}
