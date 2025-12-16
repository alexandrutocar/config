pkgs:
pkgs.custom.writeShell "locker.bash" {
  inputs = with pkgs; [waylock];
  text = builtins.readFile ./script.bash;
}
