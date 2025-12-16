pkgs:
pkgs.custom.writeShell "volume.bash" {
  inputs = with pkgs; [libnotify wireplumber];
  text = builtins.readFile ./script.bash;
}
