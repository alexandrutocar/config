pkgs:
pkgs.custom.writeShell "brightness" {
  inputs = with pkgs; [brightnessctl libnotify];
  text = builtins.readFile ./script.bash;
}
