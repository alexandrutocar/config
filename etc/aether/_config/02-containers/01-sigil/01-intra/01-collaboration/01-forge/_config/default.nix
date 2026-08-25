{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;
in {
  security.pki.certificateFiles = [
    "${pkgs.certs}/etc/ssl/anchor/intra.net.pem"
  ];

  services.resolved.enable = false;

  networking.resolvconf.enable = false;

  environment.etc."resolv.conf".text = mkForce ''
    nameserver ${sigil.containers.intra."cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a".addresses.ula}
  '';
}
