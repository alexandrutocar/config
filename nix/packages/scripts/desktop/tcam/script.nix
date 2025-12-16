pkgs:
pkgs.custom.writeShell "tcam.bash" {
  inputs = with pkgs; [brightnessctl libnotify wireplumber];
  text = builtins.readFile ./script.bash;
}
