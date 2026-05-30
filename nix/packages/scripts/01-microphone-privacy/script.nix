pkgs:
pkgs.custom.writeShell "microphone-privacy" {
  inputs = with pkgs; [libnotify wireplumber];
  text = builtins.readFile ./script.bash;
}
