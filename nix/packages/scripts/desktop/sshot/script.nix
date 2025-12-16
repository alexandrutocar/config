pkgs:
pkgs.custom.writeShell "sshot.bash" {
  inputs = with pkgs; [grim libnotify slurp wl-clipboard];
  text = builtins.readFile ./script.bash;
}
