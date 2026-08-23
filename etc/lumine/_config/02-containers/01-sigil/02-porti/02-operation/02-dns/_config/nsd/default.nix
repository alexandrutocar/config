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
        chroot = mkForce ''""'';

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

      zone = [
        {
          name = ''"ueuie.earth"'';
          zonefile = ''"${
              pkgs.writeText "ueuie.earth.zone" ''
                @   IN 	    SOA  	vega.ns.ueuie.earth.    noc.vega.ns.ueuie.earth. 	(
                    2026072801
                    10800
                    3600
                    1209600
                    3600
                )

                @           IN  NS      vega.ns.ueuie.earth.
                @           IN  NS      dara.ns.ueuie.earth.
                @           IN  NS      tara.ns.ueuie.earth.


                vega.ns     IN  AAAA    ${sigil.self.addresses.gua}
                dara.ns     IN  AAAA    ${sigil.self.addresses.gua}
                tara.ns     IN  AAAA    ${sigil.self.addresses.gua}

                @           IN  AAAA    ${sigil.containers.porti.c8ac5cd5-7563-4e68-9dce-68bb11224eab.addresses.gua}
              ''
            }"'';
        }
      ];
    };
  };
}
