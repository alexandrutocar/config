{pkgs, ...}: {
  home.packages = with pkgs; [
    zotero
  ];

  wayland.windowManager.river.settings = {
    rule-add = {
      "-app-id"."'Zotero'"."-title" = {
        "'*'" = ["ssd" ""];
        "'Zotero-Einstellungen'" = ["float"];
      };
    };
  };
}
