pkgs:
pkgs.custom.writeShell "launcher" {
  inputs = with pkgs; [tofi uwsm];
  text = builtins.readFile ./script.bash;
}
