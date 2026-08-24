{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;
in {
  services.caddy = {
    enable = true;

    email = "acme@ueuie.earth";
  };

  services.resolved.enable = false;

  networking.resolvconf.enable = false;

  environment.etc."resolv.conf".text = mkForce ''
    nameserver 2606:4700:4700::1111
  '';

  networking = {
    firewall = {
      allowedTCPPorts = [
        443 # HTTPS
      ];
    };
  };

  environment.systemPackages = with pkgs; [dig];
}
