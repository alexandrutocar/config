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

  mkContainer = name: spec: let
    inherit (lib.attrsets) mapAttrs' nameValuePair;
    inherit (lib.modules) mkDefault mkMerge;
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

        bindMounts =
          {
            # Persistence needed for credential.secret - ideally only credential.secret
            # would be persisted. But systemd imposes strict checks on the file. So for
            # now just persist the whole directory.
            "/var/lib/systemd/" = {
              hostPath = "/state/var/lib/machines/${name}/var/lib/systemd/";
              isReadOnly = false;
            };
            # Credential are bound by /etc/machine-id.
            # It is persistence to avoid a mismatch.
            "/etc/machine-id" = {
              hostPath = "/state/var/lib/machines/${name}/etc/machine-id";
              isReadOnly = false;
            };
          }
          // (spec.bindMounts or {});

        localAddress = spec.address or null;
        hostAddress = spec.gateway or null;

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
      (builtins.removeAttrs spec ["localAddress" "hostAddress" "address" "gateway" "bindMounts"])
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
    x0-com = mkContainer "x0-com" {
      gateway = "10.255.255.254";
      address = "10.0.0.1";

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

      bindMounts = {
        "/usr/" = {
          hostPath = "/state/var/lib/machines/x0-com/usr/";
        };
      };

      config = mkConfig (recursive ./containers/groups/x0/com);
    };

    x0-dns = mkContainer "x0-dns" {
      gateway = "10.255.255.253";
      address = "10.0.0.2";

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

      bindMounts = {
        "/var/lib/acme/aether.ip/" = {
          hostPath = "/state/var/lib/machines/x0-dns/var/lib/acme/aether.ip/";
          isReadOnly = false;
        };
        "/var/lib/unbound/zones/aether.ip.zone" = {
          hostPath = "/state/var/lib/machines/x0-dns/var/lib/unbound/zones/aether.ip.zone";
          isReadOnly = false;
        };
      };

      config = mkConfig (recursive ./containers/groups/x0/dns);
    };

    x0-ext = mkContainer "x0-ext" {
      gateway = "10.255.255.252";
      address = "10.0.0.3";

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
      ];

      bindMounts = {
        "/var/lib/acme/aether.ip/" = {
          hostPath = "/state/var/lib/machines/x0-ext/var/lib/acme/aether.ip/";
        };
        "/usr/share/html/" = {
          hostPath = "/state/var/lib/machines/x0-ext/usr/share/html/";
        };
      };

      config = mkConfig (recursive ./containers/groups/x0/ext);
    };

    x0-fin = mkContainer "x0-fin" {
      gateway = "10.255.255.239";
      address = "10.0.0.16";

      bindMounts = {
        "/var/lib/fava/" = {
          hostPath = "/blobs/var/lib/machines/x0-fin/var/lib/fava/";
          isReadOnly = false;
        };
      };

      config = mkConfig (recursive ./containers/groups/x0/fin);
    };

    x0-flx = mkContainer "x0-flx" {
      gateway = "10.255.255.241";
      address = "10.0.0.14";

      bindMounts = {
        "/var/lib/miniflux/admin/username.txt" = {
          hostPath = "/state/var/lib/machines/x0-flx/var/lib/miniflux/admin/username.txt";
          isReadOnly = false;
        };
        "/var/lib/miniflux/admin/password.txt" = {
          hostPath = "/state/var/lib/machines/x0-flx/var/lib/miniflux/admin/password.txt";
          isReadOnly = false;
        };
      };

      config = mkConfig (recursive ./containers/groups/x0/flx);
    };

    x0-ins = mkContainer "x0-ins" {
      gateway = "10.255.255.251";
      address = "10.0.0.4";

      bindMounts = {
        # Scrapers Secrets (API Keys)
        "/etc/prometheus/scrapers/" = {
          hostPath = "/state/var/lib/machines/x0-ins/etc/prometheus/scrapers/";
          isReadOnly = false;
        };
        # State directories (Databases)
        "/var/lib/prometheus/" = {
          hostPath = "/blobs/var/lib/machines/x0-ins/var/lib/prometheus/";
          isReadOnly = false;
        };
        "/var/lib/grafana/" = {
          hostPath = "/blobs/var/lib/machines/x0-ins/var/lib/grafana/";
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
      };

      config = mkConfig (recursive ./containers/groups/x0/ins);
    };

    x0-pgl = mkContainer "x0-pgl" {
      gateway = "10.255.255.240";
      address = "10.0.0.15";

      bindMounts = {
        "/var/lib/postgresql/" = {
          hostPath = "/blobs/var/lib/machines/x0-pgl/var/lib/postgresql/";
          isReadOnly = false;
        };
      };

      config = mkConfig (recursive ./containers/groups/x0/pgl);
    };

    x0-pim = mkContainer "x0-pim" {
      gateway = "10.255.255.249";
      address = "10.0.0.6";

      config = mkConfig (recursive ./containers/groups/x0/pim);
    };

    x0-smb = mkContainer "x0-smb" {
      gateway = "10.255.255.248";
      address = "10.0.0.7";

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

      bindMounts = {
        "/var/lib/samba/" = {
          hostPath = "/blobs/var/lib/machines/x0-smb/var/lib/samba/";
          isReadOnly = false;
        };
        "/etc/hashed/alex" = {
          hostPath = "/state/var/lib/machines/x0-smb/etc/hashed/alex";
          isReadOnly = false;
        };
        "/usr/alex/password.txt" = {
          hostPath = "/state/var/lib/machines/x0-smb/usr/alex/password.txt";
          isReadOnly = false;
        };
      };

      config = mkConfig (recursive ./containers/groups/x0/smb);
    };
    # ────────────────────────────────────────────────────────────────────────
    #
    # ▀▄▀ ▄█ ▀   █░█ █▀▀ █░█ █ █▀▀ ░ █▀▄ █▀▀ █░█
    # █░█ ░█ ▄   █▄█ ██▄ █▄█ █ ██▄ ▄ █▄▀ ██▄ ▀▄▀
    #
    # services exposed for all to see
    #
    # ────────────────────────────────────────────────────────────────────────
    x1-com = mkContainer "x1-com" {
      gateway = "10.255.255.247";
      address = "10.0.0.8";

      forwardPorts = [
        {
          containerPort = 465;
          hostPort = 5000 + 465;
          protocol = "tcp";
        }
      ];

      config = mkConfig (recursive ./containers/groups/x1/com);
    };

    x1-dns = mkContainer "x1-dns" {
      gateway = "10.255.255.246";
      address = "10.0.0.9";

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

      bindMounts = {
        "/var/lib/acme/ueuie.dev/" = {
          hostPath = "/state/var/lib/machines/x1-dns/var/lib/acme/ueuie.dev/";
          isReadOnly = false;
        };
        "/var/lib/nsd/certs/" = {
          hostPath = "/state/var/lib/machines/x1-dns/var/lib/nsd/certs/";
        };
        "/var/lib/nsd/zones/ueuie.dev.zone" = {
          hostPath = "/state/var/lib/machines/x1-dns/var/lib/nsd/zones/ueuie.dev.zone";
        };
      };

      config = mkConfig (recursive ./containers/groups/x1/dns);
    };

    x1-ext = mkContainer "x1-ext" {
      gateway = "10.255.255.245";
      address = "10.0.0.10";

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

      bindMounts = {
        "/usr/alex/blog/pages/" = {
          hostPath = "/state/var/lib/machines/x1-pwb/usr/alex/blog/pages/";
        };
        "/var/lib/acme/ueuie.dev/" = {
          hostPath = "/state/var/lib/machines/x1-ext/var/lib/acme/ueuie.dev/";
        };
        "/var/lib/acme/cache.ueuie.dev/" = {
          hostPath = "/state/var/lib/machines/x1-ext/var/lib/acme/cache.ueuie.dev/";
        };
      };

      config = mkConfig (recursive ./containers/groups/x1/ext);
    };

    x1-nix = mkContainer "x1-nix" {
      gateway = "10.255.255.250";
      address = "10.0.0.5";

      bindMounts = {
        "/var/lib/harmonia/" = {
          hostPath = "/state/var/lib/machines/x1-nix/var/lib/harmonia/";
        };

        "/nix/store" = {};

        "/nix/var/nix/db/db.sqlite" = {
          isReadOnly = false;
        };
      };

      config = mkConfig (
        recursive ./containers/groups/x1/nix
        ++ [
          inputs.harmonia.nixosModules.harmonia
        ]
      );
    };

    x1-pwb = mkContainer "x1-pwb" {
      gateway = "10.255.255.243";
      address = "10.0.0.12";

      config = mkConfig (recursive ./containers/groups/x1/pwb);
    };

    x1-wkm = mkContainer "x1-wkm" {
      gateway = "10.255.255.242";
      address = "10.0.0.13";

      bindMounts = {
        "/var/lib/uptime-kuma/" = {
          hostPath = "/blobs/var/lib/machines/x1-wkm/var/lib/uptime-kuma/";
          isReadOnly = false;
        };
      };

      config = mkConfig (recursive ./containers/groups/x1/wkm);
    };

    # ────────────────────────────────────────────────────────────────────────
    #
    # ▀▄▀ ▀█ ▀   ▀█▀ ░ █░█ █▀▀ █░█ █ █▀▀ ░ █▀▄ █▀▀ █░█
    # █░█ █▄ ▄   ░█░ ▄ █▄█ ██▄ █▄█ █ ██▄ ▄ █▄▀ ██▄ ▀▄▀
    #
    # services for projects in case their primary provider goes down
    #
    # ────────────────────────────────────────────────────────────────────────
    x2-alk = mkContainer "x2-alk" {
      gateway = "10.255.255.238";
      address = "10.0.0.17";

      config = mkConfig (recursive ./containers/groups/x2/alk);
    };
  };

  fileSystems."/blobs/var/lib/machines/x0-fin/var/lib/fava" = {
    device = "/blobs/var/lib/machines/x0-smb/var/lib/samba/private/share/04 Finanzen";
    options = ["bind"];
  };
}
