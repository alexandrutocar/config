{
  pkgs,
  lib,
  ...
}: {
  wayland.windowManager.river.settings = let
    inherit (lib.meta) getExe;

    inherit (pkgs.custom.scripts.desktop) brightness tcam tmic volume;
    inherit (pkgs) playerctl;
  in
    # Various media key mapping examples for both normal and locked mode which do
    # not have a modifier
    map (
      mode: {
        map.${mode} = {
          # Eject the optical drive (well if you still have one that is)
          "None XF86Eject" = "spawn 'eject -T'";

          # Control pulse audio volume with pamixer (https://github.com/cdemoulins/pamixer)
          "None XF86AudioMute" = "spawn '${getExe volume} /'";
          "Super XF86AudioMute" = "spawn '${getExe volume} /'";

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
          "None XF86AudioRaiseVolume" = "spawn '${getExe volume} +'";
          "None XF86AudioLowerVolume" = "spawn '${getExe volume} -'";
          "Super XF86AudioRaiseVolume" = "spawn '${getExe volume} +'";
          "Super XF86AudioLowerVolume" = "spawn '${getExe volume} -'";

          "None XF86MonBrightnessUp" = "spawn '${getExe brightness} +'";
          "None XF86MonBrightnessDown" = "spawn '${getExe brightness} -'";
          "Super XF86MonBrightnessUp" = "spawn '${getExe brightness} +'";
          "Super XF86MonBrightnessDown" = "spawn '${getExe brightness} -'";
        };
      }
    ) ["locked" "normal"];
}
