{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) mkHost';
  inherit (lib.modules) mkForce;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };

  services.nsd = {
    enable = true;

    settings = {
      server = {
        chroot = mkForce "";

        interface = [
          (mkHost' sigil.self.addresses.gua 53)
        ];

        server-count = 1;

        hide-version = true;

        identity = "AETHER";

        metrics-enable = true;
        metrics-interface = sigil.self.addresses.ula;
      };

      remote-control = {
        control-enable = false;
      };

      zone = let
        ip = {
          dns = sigil.self.addresses.gua;
          web = sigil.containers.porti.c8ac5cd5-7563-4e68-9dce-68bb11224eab.addresses.gua;
        };
      in [
        (pkgs.custom.writeAuthZone "ueuie.earth" {
          AAAA = [
            ip.web
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

          subdomains = {
            "vega.ns" = {
              AAAA = [
                ip.dns
              ];
            };
            "dara.ns" = {
              AAAA = [
                ip.dns
              ];
            };
            "tara.ns" = {
              AAAA = [
                ip.dns
              ];
            };
          };
        })
      ];
    };
  };
}
