{pkgs, ...}: {
  home.packages = with pkgs; [
    anki
  ];

  wayland.windowManager.river.settings.rule-add = {
    "-app-id"."'anki'"."-title"."'Add'" = "float";
    "-app-id"."'anki'"."-title"."'Browse *'" = "float";
  };
}
