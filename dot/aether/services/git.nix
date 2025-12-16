{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.meta) getExe;
in {
  programs.git = {
    hooks = {
      post-receive = getExe (
        pkgs.custom.writeShell "post-receive.bash" {
          inputs = with pkgs; [
            custom.depp
            git
          ];
          text = builtins.readFile ./git.bash;
        }
      );
    };
  };

  services.openssh = {
    enable = true;
    extraConfig = ''
      Match user git
        AllowTcpForwarding no
        AllowAgentForwarding no
        PasswordAuthentication no
        PermitTTY no
        X11Forwarding no
    '';
  };

  services.fail2ban = {
    enable = true;
    bantime = "24h";
    maxretry = 3;

    bantime-increment = {
      enable = true;
      rndtime = "8m";
    };
  };
}
