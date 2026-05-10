pkgs:
pkgs.custom.writeShell "launcher.bash" {
  inputs = with pkgs; [tofi uwsm];
  text = builtins.readFile ./script.bash;
}
