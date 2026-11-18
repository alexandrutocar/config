# RADII: HOST ACCESS
# ------------------
# Who may open connections to a host itself through the overlay. Covers:
#   - a host of the site reaches another host's service (SSH here)
#   - an address inside another host's /48 (a container there) does not,
#     and the drop is counted
#   - settings.hostAccess.allow lets one such address in, on its ports only
#
# One hub, running SSH and a second TCP service, both open to every source as
# NixOS opens SSH by default, and one spoke. The spoke stands in for its containers with extra addresses
# from its /48 on lo.
{
  pkgs,
  lib,
}: let
  inherit (lib.extra) ip;
  inherit (lib.modules) mkForce;

  # Throwaway key pairs, for this test only (the same as overlay.nix's).
  keys = {
    hub = {
      private = "2AVVS46QHIYUymytJUrtJDI54cfLVP4nQFiNRO+ahEk=";
      public = "Y/QOeo3Poo4IvqGukMVYB851mrEmOHcO10TNcYGOUkc=";
    };
    spoke = {
      private = "OFocfVdPOyyALlKaQN9NDtB/DwGnKTO+GpsyC1H6Wko=";
      public = "T1zIzKlWBWSzXTkcTaYbd7qfYoPPNwd4R9m0OvQ2RS8=";
    };
  };

  # The underlay: every machine on vlan 1, as 2001:db8:1::<id>.
  ids = {
    hub = 1;
    spoke = 2;
  };

  site = {
    hub = {
      id = ids.hub;
      hostAddress = "fd00:a::1";
      prefix = "fd00:a::/48";
      publicKey = keys.hub.public;
      availableNetworks = ["::/0"];
      endpoints = ["2001:db8:1::1"];
      basePort = 51820;
      openPorts = [51822];
    };

    spoke = {
      id = ids.spoke;
      hostAddress = "fd00:b::2";
      prefix = "fd00:b::/48";
      publicKey = keys.spoke.public;
      availableNetworks = ["::/0"];
    };
  };

  # Addresses in the spoke's /48, standing in for its containers: one the
  # hub lets in for SSH, one it does not.
  allowedContainer = "fd00:b::98";
  otherContainer = "fd00:b::99";

  node = name: extra: {pkgs, ...}: {
    imports = [../default.nix extra];

    virtualisation.vlans = [1];

    networking = {
      useNetworkd = true;
      nftables.enable = true;
      interfaces.eth1.ipv6.addresses = mkForce [
        {
          address = "2001:db8:1::${toString ids.${name}}";
          prefixLength = 64;
        }
      ];
    };

    environment.systemPackages = [pkgs.netcat-openbsd];

    services.radii = {
      enable = true;
      settings = {
        inherit site;
        self = name;
      };
      # Hosts give the key encrypted for themselves; a test VM has no host
      # key before it boots, so the throwaway key goes in as plain text.
      privateKey = "set as plain text below";
    };

    systemd.services.systemd-networkd.serviceConfig = {
      SetCredentialEncrypted = mkForce [];
      SetCredential = ["radii.private-key:${keys.${name}.private}"];
    };
  };

  hubExtra = {pkgs, ...}: {
    # Opens port 22 to every source, as NixOS does by default.
    services.openssh.enable = true;

    # A second service, also open to every source, that the exception does
    # not cover.
    networking.firewall.allowedTCPPorts = [2222];
    systemd.services.listener = {
      wantedBy = ["multi-user.target"];
      serviceConfig.ExecStart = "${pkgs.netcat-openbsd}/bin/nc -6 -l -k 2222";
    };

    services.radii.settings.hostAccess.allow = [
      {
        sources = [(ip.network.fromCIDR 6 "${allowedContainer}/128")];
        protocol = "tcp";
        ports = [22];
      }
    ];
  };

  spokeExtra = {
    systemd.network.networks."00-lo" = {
      matchConfig.Name = "lo";
      address = ["${allowedContainer}/128" "${otherContainer}/128"];
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "radii-host-access";

    node.specialArgs = {inherit lib;};

    nodes = {
      hub = node "hub" hubExtra;
      spoke = node "spoke" spokeExtra;
    };

    testScript = ''
      import json
      from datetime import timedelta

      LONG = timedelta(seconds=240)


      def counter(machine, name: str) -> int:
          listing = json.loads(machine.succeed(f"nft --json list counter inet radii {name}"))
          return next(item["counter"]["packets"] for item in listing["nftables"] if "counter" in item)


      def connects(source: str, port: int = 22) -> str:
          """A shell test: whether the spoke opens a TCP connection to the hub's host address from `source`."""
          return f"nc -6 -z -w 3 -s {source} fd00:a::1 {port}"


      start_all()

      for machine in (hub, spoke):
          machine.wait_for_unit("systemd-networkd.service")
      hub.wait_for_unit("sshd.service")

      spoke.wait_until_succeeds("ping -c1 -W2 fd00:a::1", timeout=LONG)

      with subtest("a host of the site reaches the hub's SSH"):
          spoke.succeed(connects("fd00:b::2"))

      with subtest("a container on another host does not, and the drop is counted"):
          before = counter(hub, "container-to-host")
          spoke.fail(connects("${otherContainer}"))
          assert counter(hub, "container-to-host") > before, "the hub did not count the dropped connection"

      with subtest("hostAccess.allow lets one container in, on its ports only"):
          spoke.succeed(connects("${allowedContainer}"))
          # Another open port stays closed to it: the exception names port 22
          # only. The spoke itself still reaches it.
          hub.wait_for_unit("listener.service")
          spoke.succeed(connects("fd00:b::2", 2222))
          spoke.fail(connects("${allowedContainer}", 2222))
    '';
  }
