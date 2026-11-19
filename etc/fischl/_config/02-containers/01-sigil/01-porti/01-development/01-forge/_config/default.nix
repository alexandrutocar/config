{
  self,
  lib,
  ...
}: let
  inherit (lib.alias) resolvers;
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
  inherit (lib.extra.trivial) mapPipeline;
  inherit (lib.modules) mkForce;
  inherit (lib.strings) concatLines;
in {
  services.resolved.enable = false;

  networking.resolvconf.enable = false;

  environment.etc."resolv.conf".text = let
    content = resolvers.cloudflare.block-malware-and-adult-content.ipv6 |> mapPipeline [ip.toCompressed (a: "nameserver ${a}")] |> concatLines;
  in
    mkForce content;

  networking = {
    nftables = {
      enable = true;
    };

    hosts = let
      colleiContainers = shortPathToContainers self.nixosConfigurations.collei.config;
    in {
      ${colleiContainers.porti.c8ac5cd5-7563-4e68-9dce-68bb11224eab |> getULA |> ip.toCompressed} = [
        "guard.ueuie.earth"
      ];
    };
  };
}
