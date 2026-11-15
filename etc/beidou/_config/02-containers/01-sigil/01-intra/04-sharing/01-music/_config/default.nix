{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.modules) mkForce;
in {
  services.resolved.enable = false;

  networking.resolvconf.enable = false;

  environment.etc."resolv.conf".text = let
    nsAddress = sigil.containers.intra.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a.addresses.ipv6.ula;
  in
    mkForce ''
      nameserver ${nsAddress |> ip.toCompressed}
    '';
}
