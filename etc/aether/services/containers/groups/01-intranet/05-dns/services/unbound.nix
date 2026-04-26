# ────────────────────────────────────────────────────────────────────────
#
# █░█ █▄░█ █▄▄ █▀█ █░█ █▄░█ █▀▄
# █▄█ █░▀█ █▄█ █▄█ █▄█ █░▀█ █▄▀
#
# unbound, dns, resolver...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;

  inherit (container) self intranet-monitoring;
in {
  services = {
    # UNBOUND
    # -------
    unbound = {
      enable = true;

      package = pkgs.unbound.override {
        withSystemd = true;
        withDNSTAP = true;
        withECS = true;
        withDoH = true;
        withTFO = true;
        withRedis = true;
      };

      settings = {
        server = mkMerge [
          {
            interface = map (port: "${self.localAddress}@${toString port}") [53 853];

            quic-port = 853;
            tls-port = 853;

            do-udp = true;
            do-tcp = true;

            tls-service-key = "/var/lib/acme/aether.ip/key.pem";
            tls-service-pem = "/var/lib/acme/aether.ip/fullchain.pem";
          }
          {
            # https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html#unbound-conf-access-control
            access-control = map (address: "${address} allow") [
              # Containers
              "10.0.0.0/24"

              # Host
              "169.254.0.0/16"

              # Virtual Private Network
              "172.16.1.2/32"
              "172.16.1.3/32"

              "fd31::1:2/128"
              "fd31::1:3/128"
            ];
          }
          {
            deny-any = true;
          }
          {
            aggressive-nsec = true;
            use-caps-for-id = true;

            hide-identity = true;
            hide-version = false;

            harden-algo-downgrade = true;
            harden-below-nxdomain = true;

            harden-large-queries = true;
            harden-referral-path = true;

            harden-dnssec-stripped = true;
            harden-unverified-glue = true;
          }
          {
            infra-host-ttl = 60;
          }
          {
            serve-expired = true;
            prefetch = true;
            prefetch-key = true;
          }
          {
            # https://nlnetlabs.nl/documentation/unbound/howto-optimise/
            num-threads = 8;

            key-cache-slabs = 8;
            infra-cache-slabs = 8;
            msg-cache-slabs = 8;
            rrset-cache-slabs = 8;

            # Due to `malloc` overhead, the total memory usage
            # is likely to rise to double (or 2.5x) the total
            # cache memory that is entered into the config.
            rrset-cache-size = "128m";
            msg-cache-size = "64m";

            outgoing-range = 64;
            num-queries-per-thread = 32;
          }
          {
            log-queries = true;
            log-replies = true;
          }
          {
            extended-statistics = true;
          }
          {
            val-clean-additional = true;
            val-permissive-mode = false;
          }
        ];

        forward-zone = [
          {
            name = ".";

            forward-tls-upstream = true;

            forward-addr = [
              "1.1.1.1@853#cloudflare-dns.com"
              "1.0.0.1@853#cloudflare-dns.com"
            ];
          }
        ];

        auth-zone = [
          {
            name = "aether.ip";
            zonefile = "${../etcetera/zones/aether.ip.zone}";
          }
        ];

        # Control socket is used
        # by a metrics exporter.
        remote-control = {
          control-enable = true;
          control-interface = "/var/run/unbound/unbound.sock";
        };
      };
    };

    # LOGROTATE
    # ---------
    logrotate = {
      settings = {
        "/var/log/unbound/unbound.log" = {
          daily = true;
          rotate = 7;
          missingok = true;
          compress = true;
          delaycompress = true;
          notifempty = true;
          postrotate = ''
            unbound-control log_reopen
          '';
          endscript = true;
        };
      };
    };
  };

  boot.kernel.sysctl = {
    "net.core.rmem_max" = 4194304;
    "net.core.wmem_max" = 4194304;
  };
}
