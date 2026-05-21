pkgs:
pkgs.custom.writeShell "microphone-privacy" {
  inputs = with pkgs; [brightnessctl libnotify wireplumber];
  text = builtins.readFile ./script.bash;
}
