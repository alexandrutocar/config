pkgs:
pkgs.custom.writeShell "screen-locker" {
  inputs = with pkgs; [waylock];
  text = builtins.readFile ./script.bash;
}
