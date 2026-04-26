{pkgs, ...}: {
  home.packages = with pkgs; [zathura];

  wayland.windowManager.river.settings.rule-add = let
    app-id = "'org.pwmt.zathura''";
  in {
    "-app-id".${app-id} = ["ssd" "float"];
  };
}
