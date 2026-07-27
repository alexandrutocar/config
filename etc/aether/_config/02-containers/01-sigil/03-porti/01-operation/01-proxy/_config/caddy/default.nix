{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;
in let
  resolver = {
    inherit (sigil.containers.intra.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a.addresses) ula;
  };
in {
  services.caddy = {
    enable = true;

    email = "acme@ueuie.earth";
  };

  services.resolved.enable = false;

  networking.resolvconf.enable = false;

  environment.etc."resolv.conf".text = mkForce ''
    nameserver ${resolver.ula}
  '';

  networking = {
    firewall = {
      allowedTCPPorts = [
        443 # HTTPS
        80 # HTTP
      ];
    };
  };

  environment.systemPackages = with pkgs; [dig];
}
