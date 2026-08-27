{pkgs, ...}: let
  kdl = pkgs.formats.kdl {
    version = 1;
  };
in {
  programs = {
    zellij = {
      enable = true;

      settings = let
        inherit (kdl.lib) node;
      in [
        (node "show_startup_tips" null [false] {} [])
        (node "default_shell" null ["zsh"] {} [])
      ];

      plugins = with pkgs.zellijPlugins; [zjstatus];

      exitShellOnExit = true;
      attachExistingSession = true;
    };
  };
}
