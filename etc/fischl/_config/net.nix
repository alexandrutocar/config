{
  self,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
  inherit (lib.lists) singleton;
in let
  beidouContainers = shortPathToContainers self.nixosConfigurations.beidou.config;
in {
  imports = singleton (self + "/etc/shared/01-settings/net.nix");

  # DNS (INTERNAL)
  # --------------
  networking.nameservers = [
    (beidouContainers.intra.cd4e7991-27fc-425b-9f9c-a0b3ec1b4f1a |> getULA |> ip.toCompressed)
  ];

  services.resolved = {
    enable = true;

    settings = {
      Resolve = {
        Domains = ["~intra.net.internal" "~hosts.net.internal"];
      };
    };
  };
  # CERTIFICATE
  # -----------
  security.pki.certificateFiles = [
    "${pkgs.certs}/etc/ssl/anchor/intra.net.pem"
  ];
}
