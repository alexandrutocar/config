{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.meta) getExe;
in {
  xdg.desktopEntries.connect-to-pool = let
    script = pkgs.custom.writeShell "connect-to-pool" {
      inputs = with pkgs; [curl findutils foot libnotify pup tofi];
      text = builtins.readFile ./script.bash;
      env = {
        SSL_CERT_FILE = ./certificates/gsg.informatik.uni-bonn.de.chain.pem;
      };
    };
  in {
    name = "Connect to Pool";
    exec = "${getExe script}";

    type = "Application";

    categories = ["System"];

    settings = {
      Comment = "Reboot the system";
    };

    terminal = false;
  };
}
