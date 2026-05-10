_: {
  programs.zathura = {
    enable = true;
    
    options = {
      selection-clipboard = "clipboard";
    };
  };

  wayland.windowManager.river.settings = {
    rule-add = {
      "-app-id"."'org.pwmt.zathura'" = ["ssd" "float"];
    };
  };
}
