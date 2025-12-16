{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.meta) getExe;
in {
  programs.git = {
    hooks = {
      post-receive = getExe (
        pkgs.custom.writeShell "post-receive.bash" {
          inputs = with pkgs; [
            custom.depp
            git
          ];
          text = builtins.readFile ./git.bash;
        }
      );
    };
  };
}
