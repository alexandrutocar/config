# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▀█ █▀█ ▀█▀ █ █▀▀ █▄█
# ▄█ █▀▀ █▄█ ░█░ █ █▀░ ░█░
#
# spotify, player...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  home.packages = with pkgs; [
    wl-clipboard
  ];

  programs.spotify-player = {
    enable = true;
    package = pkgs.spotify-player.override {
      withImage = false;
      withSixel = false;
    };
    settings = {
      theme = "default";
      playback_window_position = "Bottom";
      copy_command = {
        command = "${pkgs.wl-clipboard}/bin/wl-copy";
        args = [];
      };
      device = {
        name = "Laptop";
        device_type = "computer";
        audio_cache = true;
        normalization = true;
      };
      notify_timeout_in_secs = 5;
    };
    themes = [
      {
        name = "default";
        palette = {
          black = "black";
          red = "red";
          green = "green";
          yellow = "yellow";
          blue = "blue";
          magenta = "magenta";
          cyan = "cyan";
          white = "white";
          bright_black = "bright_black";
          bright_red = "bright_red";
          bright_green = "bright_green";
          bright_yellow = "bright_yellow";
          bright_blue = "bright_blue";
          bright_magenta = "bright_magenta";
          bright_cyan = "bright_cyan";
          bright_white = "bright_white";
        };
        component_style = {
          block_title = {fg = "Magenta";};
          border = {};
          playback_track = {
            fg = "Cyan";
            modifiers = ["Bold"];
          };
          playback_artists = {
            fg = "Cyan";
            modifiers = ["Bold"];
          };
          playback_album = {fg = "Yellow";};
          playback_metadata = {fg = "BrightBlack";};
          playback_progress_bar = {
            bg = "BrightBlack";
            fg = "Green";
          };
          current_playing = {
            fg = "Green";
            modifiers = ["Bold"];
          };
          page_desc = {
            fg = "Cyan";
            modifiers = ["Bold"];
          };
          table_header = {fg = "Blue";};
          selection = {modifiers = ["Bold" "Reversed"];};
        };
      }
    ];
  };
}
