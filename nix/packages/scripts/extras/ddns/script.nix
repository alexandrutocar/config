pkgs:
pkgs.writeShellApplication {
  name = "ddns.bash";
  runtimeInputs = with pkgs; [curl util-linux];
  text = builtins.readFile ./script.sh;
}
