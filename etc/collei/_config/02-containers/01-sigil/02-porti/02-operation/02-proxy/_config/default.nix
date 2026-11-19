{lib, ...}: let
  inherit (lib.alias) resolvers;
  inherit (lib.extra) ip;
  inherit (lib.extra.trivial) mapPipeline;
  inherit (lib.modules) mkForce;
  inherit (lib.strings) concatLines;
in {
  services.resolved.enable = false;

  networking.resolvconf.enable = false;

  environment.etc."resolv.conf".text = let
    content = resolvers.cloudflare.standard.ipv6 |> mapPipeline [ip.toCompressed (a: "nameserver ${a}")] |> concatLines;
  in
    mkForce content;
}
