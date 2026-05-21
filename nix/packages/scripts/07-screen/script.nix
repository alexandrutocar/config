pkgs:
pkgs.custom.writeShell "screen" {
  inputs = with pkgs; [grim libnotify slurp wl-clipboard];
  text = builtins.readFile ./script.bash;
}
