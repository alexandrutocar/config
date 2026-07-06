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

        # Metrics
        metrics-enable = true;
        metrics-interface = "::";
      };

      remote-control = {
        control-enable = false;
        # control-interface = "0.0.0.0";
        # server-key-file = ''"/var/lib/nsd/certs/server.key"'';
        # server-cert-file = ''"/var/lib/nsd/certs/server.pem"'';
        # control-key-file = ''"/var/lib/nsd/certs/control.key"'';
        # control-cert-file = ''"/var/lib/nsd/certs/control.pem"'';
      };

      zone = [
        {
          name = ''"ueuie.earth"'';
          zonefile = ''"${
              pkgs.writeText "ueuie.earth.zone" ''
                @   IN 	    SOA  	aether.ns.ueuie.earth.    noc.aether.ns.ueuie.earth. 	(
                    2026072602
                    300
                    60
                    86400
                    60
                )

                @           IN  NS      aether.ns.ueuie.earth.

                aether.ns   IN  AAAA    ${sigil.self.addresses.gua}

                @           IN  AAAA    2a00:5ba0:8009:5f4c:696d:bcb3:9dcd:8641
              ''
            }"'';
        }
      ];
    };
  };

  environment.systemPackages = with pkgs; [tcpdump];
}
