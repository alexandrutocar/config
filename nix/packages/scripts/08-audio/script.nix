pkgs:
pkgs.custom.writeShell "audio" {
  inputs = with pkgs; [libnotify wireplumber];
  text = builtins.readFile ./script.bash;
}
