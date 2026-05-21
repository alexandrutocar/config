pkgs:
pkgs.custom.writeShell "keyboard-lighting" {
  inputs = with pkgs; [brightnessctl libnotify];
  text = builtins.readFile ./script.bash;
}
