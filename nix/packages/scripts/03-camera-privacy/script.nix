pkgs:
pkgs.custom.writeShell "camera-privacy" {
  inputs = with pkgs; [brightnessctl libnotify wireplumber];
  text = builtins.readFile ./script.bash;
}
