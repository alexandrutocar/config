pkgs:
pkgs.writeShellApplication {
  name = "backup.bash";
  runtimeInputs = with pkgs; [coreutils libnotify systemd];
  text = builtins.readFile ./script.bash;
}
