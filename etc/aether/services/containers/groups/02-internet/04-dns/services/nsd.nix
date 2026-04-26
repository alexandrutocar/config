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
  pkgs,
  lib,
  ...
}: let
  inherit (container) self;

  inherit (lib.meta) getExe';
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
          zonefile = ''"${../etcetera/zones/ueuie.dev.zone}"'';
        }
      ];
    };
  };

  systemd.paths.nsd-n8n-reload = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathModified = "/etc/nsd/zones/ueuie.dev.soa.zone";
  };

  systemd.services.nsd-n8n-reload = {
    description = "Reload NSD when n8n zone file changes";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${getExe' pkgs.nsd "nsd-control"} reload \"ueuie.dev\"";
    };
  };
}
