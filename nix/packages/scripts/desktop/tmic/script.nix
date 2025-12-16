pkgs:
pkgs.custom.writeShell "tmic.bash" {
  inputs = with pkgs; [brightnessctl libnotify wireplumber];
  text = builtins.readFile ./script.bash;
}
