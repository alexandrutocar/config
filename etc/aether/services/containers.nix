# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ █▄░█ ▀█▀ ▄▀█ █ █▄░█ █▀▀ █▀█ █▀
# █▄▄ █▄█ █░▀█ ░█░ █▀█ █ █░▀█ ██▄ █▀▄ ▄█
#
# containers, nat, firewall, networking, binds...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}: let
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkMerge;

  mkContainer = name: spec: let
    inherit (lib.attrsets) mapAttrs' nameValuePair;
    inherit (lib.modules) mkDefault;
  in
    mkMerge [
      {
        ephemeral = mkDefault true;
        autoStart = true;

        # ────────────────────────────────────────────────────────────────────────
        # TODO: Change to "pick", but first find out how to bind mount
        #       with correct ownership.
        # ────────────────────────────────────────────────────────────────────────
        privateUsers = "no";

        privateNetwork = true;

        specialArgs = mkMerge [
          {
            inherit lib self inputs;
            container =
              {
                self = builtins.removeAttrs spec ["specialArgs" "bindMounts" "config"];
              }
              // (
                config.containers
                |> mapAttrs' (
                  name: settings: nameValuePair name settings.specialArgs.container.self
                )
              );
          }
        ];
      }
      spec
    ];

  mkConfig = config: let
    inherit (lib.custom.files.list) recursive;
  in
    _: {
      imports =
        recursive ./containers/shared/settings ++ config;
    };
in {
  # ────────────────────────────────────────────────────────────────────────
  # TODO: This is a mess...
  # ────────────────────────────────────────────────────────────────────────
  containers = let
    inherit (lib.custom.files.list) recursive;
  in {
    # ────────────────────────────────────────────────────────────────────────
    #
    # ▀▄▀ █▀█ ▀   ▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █▀█ ░ █ █▀█
    # █░█ █▄█ ▄   █▀█ ██▄ ░█░ █▀█ ██▄ █▀▄ ▄ █ █▀▀
    #
    # private services for personal use (primarily)
    #
    # ────────────────────────────────────────────────────────────────────────
    intranet-accounting = mkContainer "intranet-accounting" {
      hostAddress = "10.255.255.254";
      localAddress = "10.0.0.1";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/01-accounting/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/01-accounting/etc/machine-id";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/01-accounting);
    };

    intranet-gateway = mkContainer "intranet-gateway" {
      hostAddress = "10.255.255.253";
      localAddress = "10.0.0.2";

      forwardPorts = [
        {
          containerPort = 80;
          hostPort = 80;
          protocol = "tcp";
        }
        {
          containerPort = 443;
          hostPort = 443;
          protocol = "tcp";
        }
        {
          containerPort = 11434;
          hostPort = 11434;
          protocol = "tcp";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/02-gateway/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/02-gateway/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/acme/aether.ip/" = {
            hostPath = "/state/var/lib/machines/01-intranet/02-gateway/var/lib/acme/aether.ip/";
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/02-gateway);
    };

    intranet-alkaline = mkContainer "intranet-alkaline" {
      hostAddress = "10.255.255.252";
      localAddress = "10.0.0.3";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/03-alkaline/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/03-alkaline/etc/machine-id";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/03-alkaline);
    };

    intranet-email = mkContainer "intranet-email" {
      hostAddress = "10.255.255.251";
      localAddress = "10.0.0.4";

      forwardPorts = [
        {
          containerPort = 25;
          hostPort = 25;
          protocol = "tcp";
        }
        {
          containerPort = 465;
          hostPort = 465;
          protocol = "tcp";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/04-email/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/04-email/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/usr/" = {
            hostPath = "/state/var/lib/machines/01-intranet/04-email/usr/";
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/04-email);
    };

    intranet-feed = mkContainer "intranet-feed" {
      hostAddress = "10.255.255.250";
      localAddress = "10.0.0.5";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/05-feed/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/05-feed/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/miniflux/admin/username.txt" = {
            hostPath = "/state/var/lib/machines/01-intranet/05-feed/var/lib/miniflux/admin/username.txt";
            isReadOnly = false;
          };
          "/var/lib/miniflux/admin/password.txt" = {
            hostPath = "/state/var/lib/machines/01-intranet/05-feed/var/lib/miniflux/admin/password.txt";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/05-feed);
    };

    intranet-dns = mkContainer "intranet-dns" {
      hostAddress = "10.255.255.249";
      localAddress = "10.0.0.6";

      forwardPorts = [
        {
          containerPort = 53;
          hostPort = 53;
          protocol = "tcp";
        }
        {
          containerPort = 53;
          hostPort = 53;
          protocol = "udp";
        }
        {
          containerPort = 853;
          hostPort = 853;
          protocol = "tcp";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/06-dns/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/06-dns/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/acme/aether.ip/" = {
            hostPath = "/state/var/lib/machines/01-intranet/06-dns/var/lib/acme/aether.ip/";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/06-dns);
    };

    intranet-ml = mkContainer "intranet-ml" {
      hostAddress = "10.255.255.248";
      localAddress = "10.0.0.7";

      forwardPorts = [
        {
          containerPort = 8080;
          hostPort = 11443;
          protocol = "tcp";
        }
      ];

      allowedDevices = [
        {
          node = "/dev/nvidia0";
          modifier = "rw";
        }
        {
          node = "/dev/nvidiactl";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-caps*";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-modeset";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-uvm";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-uvm-tools";
          modifier = "rw";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/07-ml/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/07-ml/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/models" = {
            hostPath = "/state/var/lib/machines/01-intranet/07-ml/var/lib/models";
            isReadOnly = false;
          };
        }
        {
          "/dev/nvidia0" = {
            hostPath = "/dev/nvidia0";
          };
          "/dev/nvidiactl" = {
            hostPath = "/dev/nvidiactl";
          };
          "/dev/nvidia-modeset" = {
            hostPath = "/dev/nvidia-modeset";
          };
          "/dev/nvidia-uvm" = {
            hostPath = "/dev/nvidia-uvm";
          };
          "/dev/nvidia-uvm-tools" = {
            hostPath = "/dev/nvidia-uvm-tools";
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/07-ml);
    };

    intranet-dav = mkContainer "intranet-dav" {
      hostAddress = "10.255.255.247";
      localAddress = "10.0.0.8";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/08-dav/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/08-dav/etc/machine-id";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/08-dav);
    };

    intranet-coder = mkContainer "intranet-coder" {
      hostAddress = "10.255.255.246";
      localAddress = "10.0.0.9";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/10-coder/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/10-coder/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/docker/" = {
            hostPath = "/blobs/var/lib/machines/01-intranet/10-coder/var/lib/docker/";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/10-coder);
    };

    intranet-storage = mkContainer "intranet-storage" {
      hostAddress = "10.255.255.245";
      localAddress = "10.0.0.10";

      forwardPorts = [
        {
          containerPort = 139;
          hostPort = 139;
          protocol = "tcp";
        }
        {
          containerPort = 445;
          hostPort = 445;
          protocol = "tcp";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/11-storage/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/11-storage/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/samba/private/share/" = {
            hostPath = "/archive/share/";
            isReadOnly = false;
          };
          "/var/lib/samba/" = {
            hostPath = "/blobs/var/lib/machines/01-intranet/11-storage/var/lib/samba/";
            isReadOnly = false;
          };
          "/etc/hashed/alex" = {
            hostPath = "/state/var/lib/machines/01-intranet/11-storage/etc/hashed/alex";
            isReadOnly = false;
          };
          "/usr/alex/password.txt" = {
            hostPath = "/state/var/lib/machines/01-intranet/11-storage/usr/alex/password.txt";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/11-storage);
    };

    intranet-database = mkContainer "intranet-database" {
      hostAddress = "10.255.255.244";
      localAddress = "10.0.0.11";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/12-database/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/12-database/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/postgresql/" = {
            hostPath = "/blobs/var/lib/machines/01-intranet/12-database/var/lib/postgresql/";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/12-database);
    };

    intranet-monitoring = mkContainer "intranet-monitoring" {
      hostAddress = "10.255.255.243";
      localAddress = "10.0.0.12";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/01-intranet/13-monitoring/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/01-intranet/13-monitoring/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          # Scrapers Secrets (API Keys)
          "/etc/prometheus/scrapers/" = {
            hostPath = "/state/var/lib/machines/01-intranet/13-monitoring/etc/prometheus/scrapers/";
            isReadOnly = false;
          };
          # State directories (Databases)
          "/var/lib/prometheus/" = {
            hostPath = "/blobs/var/lib/machines/01-intranet/13-monitoring/var/lib/prometheus/";
            isReadOnly = false;
          };
          "/var/lib/grafana/" = {
            hostPath = "/blobs/var/lib/machines/01-intranet/13-monitoring/var/lib/grafana/";
            isReadOnly = false;
          };
          # This is required so that node exporter
          # can collect metrics from the host.
          "/host/root" = {
            hostPath = "/";
          };
          "/host/sys" = {
            hostPath = "/sys";
          };
          "/host/proc" = {
            hostPath = "/proc";
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/01-intranet/13-monitoring);
    };

    # ────────────────────────────────────────────────────────────────────────
    #
    # ▀▄▀ ▄█ ▀   █░█ █▀▀ █░█ █ █▀▀ ░ █▀▄ █▀▀ █░█
    # █░█ ░█ ▄   █▄█ ██▄ █▄█ █ ██▄ ▄ █▄▀ ██▄ ▀▄▀
    #
    # services exposed for all to see
    #
    # ────────────────────────────────────────────────────────────────────────
    internet-harmonia = mkContainer "internet-harmonia" {
      hostAddress = "10.255.255.242";
      localAddress = "10.0.0.13";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/02-internet/01-harmonia/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/02-internet/01-harmonia/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/harmonia/" = {
            hostPath = "/state/var/lib/machines/02-internet/01-harmonia/var/lib/harmonia/";
          };

          "/nix/store" = {};

          "/nix/var/nix/db/db.sqlite" = {
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (
        recursive ./containers/groups/02-internet/01-harmonia
        ++ [
          inputs.harmonia.nixosModules.harmonia
        ]
      );
    };

    internet-gateway = mkContainer "internet-gateway" {
      hostAddress = "10.255.255.241";
      localAddress = "10.0.0.14";

      forwardPorts = [
        {
          containerPort = 443;
          hostPort = 5000 + 443;
          protocol = "tcp";
        }
        {
          containerPort = 80;
          hostPort = 5000 + 80;
          protocol = "tcp";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/02-internet/02-gateway/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/02-internet/02-gateway/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/acme/ueuie.dev/" = {
            hostPath = "/state/var/lib/machines/02-internet/02-gateway/var/lib/acme/ueuie.dev/";
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/02-internet/02-gateway);
    };

    internet-uptime = mkContainer "internet-uptime" {
      hostAddress = "10.255.255.240";
      localAddress = "10.0.0.15";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/02-internet/03-uptime/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/02-internet/03-uptime/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/uptime-kuma/" = {
            hostPath = "/blobs/var/lib/machines/02-internet/03-uptime/var/lib/uptime-kuma/";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/02-internet/03-uptime);
    };

    internet-email = mkContainer "internet-email" {
      hostAddress = "10.255.255.239";
      localAddress = "10.0.0.16";

      forwardPorts = [
        {
          containerPort = 465;
          hostPort = 5000 + 465;
          protocol = "tcp";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/02-internet/04-email/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/02-internet/04-email/etc/machine-id";
            isReadOnly = false;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/02-internet/04-email);
    };

    internet-dns = mkContainer "internet-dns" {
      hostAddress = "10.255.255.238";
      localAddress = "10.0.0.17";

      forwardPorts = [
        {
          containerPort = 53;
          hostPort = 5000 + 53;
          protocol = "tcp";
        }
        {
          containerPort = 53;
          hostPort = 5000 + 53;
          protocol = "udp";
        }
        {
          containerPort = 853;
          hostPort = 5000 + 853;
          protocol = "udp";
        }
      ];

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/02-internet/06-dns/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/02-internet/06-dns/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/acme/ueuie.dev/" = {
            hostPath = "/state/var/lib/machines/02-internet/06-dns/var/lib/acme/ueuie.dev/";
            isReadOnly = false;
          };
          "/var/lib/nsd/certs/" = {
            hostPath = "/state/var/lib/machines/02-internet/06-dns/var/lib/nsd/certs/";
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/02-internet/06-dns);
    };

    internet-xmpp = mkContainer "internet-xmpp" {
      hostAddress = "10.255.255.237";
      localAddress = "10.0.0.18";

      bindMounts = mkMerge [
        {
          "/var/lib/systemd/" = {
            hostPath = "/state/var/lib/machines/02-internet/07-xmpp/var/lib/systemd/";
            isReadOnly = false;
          };
          "/etc/machine-id" = {
            hostPath = "/state/var/lib/machines/02-internet/07-xmpp/etc/machine-id";
            isReadOnly = false;
          };
        }
        {
          "/var/lib/prosody/" = {
            hostPath = "/state/var/lib/machines/02-internet/07-xmpp/var/lib/prosody/";
            isReadOnly = false;
          };
          "/etc/secrets/coturn.auth" = {
            hostPath = "/state/var/lib/machines/02-internet/07-xmpp/etc/secrets/coturn.auth";
            isReadOnly = true;
          };
        }
      ];

      config = mkConfig (recursive ./containers/groups/02-internet/07-xmpp);
    };
  };
}
