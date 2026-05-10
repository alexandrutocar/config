pkgs:
pkgs.custom.writeShell "backlighting.bash" {
  inputs = with pkgs; [brightnessctl libnotify];
  text = builtins.readFile ./script.bash;
}
