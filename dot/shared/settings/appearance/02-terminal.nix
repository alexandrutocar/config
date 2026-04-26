{lib, ...}: let
  inherit (lib.modules) mkMerge;
in {
  home.sessionVariables.TERMINAL = "foot";

  programs.foot = {
    enable = true;

    settings = {
      main.font = "Tamsyn:size=11";
    };
  };

  wayland.windowManager.river.settings = mkMerge [
    {
      rule-add."-app-id"."'foot'"."-title" = {
        "'Yazi: *'"."dimensions" = "750 500";
        "'*'" = "float";
      };
    }
  ];
}
