{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra) ip url;
  inherit (lib.extra.sigil) getGUA getULA;
  inherit (lib.modules) mkForce;
in {
  services.nsd = {
    enable = true;

    settings = {
      server = {
        chroot = mkForce "";

        interface = let
          inherit (url.interface) fromParts toNLnetLabs;
        in [
          (toNLnetLabs (fromParts (sigil.self |> getGUA) 53))
        ];

        server-count = 1;

        hide-version = true;

        identity = "COLLEI";

        metrics-enable = true;
        metrics-interface = sigil.self |> getULA |> ip.toCompressed;
      };

      remote-control = {
        control-enable = false;
      };

      zone = let
        target = {
          proxy = {
            _main = sigil.containers.porti.c8ac5cd5-7563-4e68-9dce-68bb11224eab |> getGUA |> ip.toCompressed;
          };
          dns = sigil.self |> getGUA |> ip.toCompressed;
        };
      in [
        (pkgs.custom.writeAuthZone "ueuie.earth" {
          AAAA = with target.proxy; [
            _main
          ];

          SOA = {
            nameServer = "vega.ns.ueuie.earth.";
            minimum = 3600;
            serial = 2026082801;
            retry = 3600;
            expire = 1209600;
            refresh = 10800;
            adminEmail = "noc@vega.ns.ueuie.earth";
          };

          NS = [
            "vega.ns.ueuie.earth."
            "dara.ns.ueuie.earth."
            "tara.ns.ueuie.earth."
          ];

          subdomains = let
            AAAA = [
              target.dns
            ];
          in {
            "vega.ns" = {
              inherit AAAA;
            };
            "dara.ns" = {
              inherit AAAA;
            };
            "tara.ns" = {
              inherit AAAA;
            };
          };
        })
      ];
    };
  };
}
