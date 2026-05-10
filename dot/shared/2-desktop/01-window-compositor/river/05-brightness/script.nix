pkgs:
pkgs.custom.writeShell "brightness.bash" {
  inputs = with pkgs; [brightnessctl libnotify];
  text = builtins.readFile ./script.bash;
}
