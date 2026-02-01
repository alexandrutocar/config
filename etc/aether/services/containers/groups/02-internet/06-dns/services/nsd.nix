# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀ █▀▄
# █░▀█ ▄█ █▄▀
#
# nsd, dns, ueuie.dev...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  lib,
  ...
}: let
  inherit (container) self;

  inherit (lib.modules) mkForce;
in {
  services.nsd = {
    enable = true;

    settings = {
      server = {
        chroot = mkForce ''""'';

        interface = with self; [
          "${localAddress}@53"
          "${localAddress}@583"
        ];

        server-count = 1;

        # ────────────────────────────────────────────────────────────────────────
        # TODO: Compile the right chain.pem.
        # ────────────────────────────────────────────────────────────────────────
        # tls-cert-bundle = "/var/lib/acme/ueuie.dev/chain.pem";

        # Transport Layer Security.
        tls-service-key = "/var/lib/acme/ueuie.dev/key.pem";
        tls-service-pem = "/var/lib/acme/ueuie.dev/fullchain.pem";

        hide-version = true;

        identity = "AETHER_X1";

        # Metrics
        metrics-enable = true;
        metrics-interface = self.localAddress;
      };

      remote-control = {
        control-enable = true;
        control-interface = self.localAddress;
        server-key-file = ''"/var/lib/nsd/certs/server.key"'';
        server-cert-file = ''"/var/lib/nsd/certs/server.pem"'';
        control-key-file = ''"/var/lib/nsd/certs/control.key"'';
        control-cert-file = ''"/var/lib/nsd/certs/control.pem"'';
      };

      pattern = [
        {
          name = "default";
          zonefile = ''"/var/lib/nsd/zones/%s.zone"'';
        }
      ];

      zone = [
        {
          name = ''"ueuie.dev"'';
          zonefile = ''"${./zones/ueuie.dev.zone}"'';
        }
      ];
    };
  };
}
