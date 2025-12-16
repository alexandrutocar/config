pkgs:
pkgs.custom.writeShell "glue.bash" {
  inputs = with pkgs; [curl gnugrep jq];
  text = builtins.readFile ./script.bash;
}
