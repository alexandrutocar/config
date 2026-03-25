pkgs:
pkgs.custom.writeShell "pools.bash" {
  inputs = with pkgs; [curl findutils foot libnotify pup tofi];
  text = builtins.readFile ./script.bash;
  env = {
    SSL_CERT_FILE = ./gsg.informatik.uni-bonn.de.chain.pem;
  };
}
