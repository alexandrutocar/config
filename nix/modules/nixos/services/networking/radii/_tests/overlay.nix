# RADII OVERLAY
# -------------
# Two hubs and two spokes on one underlay, running radii as hosts do. Covers
# what cannot be tried on live hosts before the switch:
#   - the watchdog moves a tunnel past a dead endpoint
#   - an IPv4-only spoke uses only IPv4 endpoints
#   - spokes reach each other through a hub, whichever hub each picks
#   - a spoke's forged source is dropped at the hub (WireGuard's AllowedIPs)
#   - a source the site does not route is dropped from a hub's tunnel
#   - a host's own networks are dropped when they come from the uplink
#   - traffic moves to the other hub when one fails
{
  pkgs,
  lib,
}: let
  # Throwaway key pairs, for this test only.
  keys = {
    hub1 = {
      private = "2AVVS46QHIYUymytJUrtJDI54cfLVP4nQFiNRO+ahEk=";
      public = "Y/QOeo3Poo4IvqGukMVYB851mrEmOHcO10TNcYGOUkc=";
    };
    hub2 = {
      private = "kLjvSMIdlj0+wZs41byQMrRbuYLFeuJuiNNQl7KDwkU=";
      public = "IxikoVyjE94GKW3Ytu7sxFCliLidpe5KxQEaw0qFO2Y=";
    };
    spoke1 = {
      private = "OFocfVdPOyyALlKaQN9NDtB/DwGnKTO+GpsyC1H6Wko=";
      public = "T1zIzKlWBWSzXTkcTaYbd7qfYoPPNwd4R9m0OvQ2RS8=";
    };
    spoke2 = {
      private = "yMWIYYazxiq3wPo9BL4cEIwgnz6++ODj+5d3s/DDy1Q=";
      public = "SRMO23MjldNrfhDJ9x5HftNbRtUAyq240zN3kJWyL2c=";
    };
  };

  # The underlay: every machine on vlan 1, as 192.168.1.<id> and
  # 2001:db8:1::<id>.
  ids = {
    hub1 = 1;
    hub2 = 2;
    spoke1 = 3;
    spoke2 = 4;
  };

  site = {
    # Its first endpoint answers nobody: tunnels start there, and the
    # watchdog has to move them on.
    hub1 = {
      id = ids.hub1;
      hostAddress = "fd00:a::1";
      prefix = "fd00:a::/48";
      publicKey = keys.hub1.public;
      availableNetworks = ["0.0.0.0/0" "::/0"];
      endpoints = ["2001:db8:1::99" "2001:db8:1::1" "192.168.1.1"];
      basePort = 51820;
    };

    hub2 = {
      id = ids.hub2;
      hostAddress = "fd00:b::1";
      prefix = "fd00:b::/48";
      publicKey = keys.hub2.public;
      availableNetworks = ["0.0.0.0/0" "::/0"];
      endpoints = ["2001:db8:1::2" "192.168.1.2"];
      basePort = 52820;
    };

    # Dual stack, with only a host address.
    spoke1 = {
      id = ids.spoke1;
      hostAddress = "fd00:c::3";
      publicKey = keys.spoke1.public;
      availableNetworks = ["0.0.0.0/0" "::/0"];
    };

    # IPv4 only, with a /48.
    spoke2 = {
      id = ids.spoke2;
      hostAddress = "fd00:d::4";
      prefix = "fd00:d::/48";
      publicKey = keys.spoke2.public;
      availableNetworks = ["0.0.0.0/0"];
    };
  };

  node = name: {
    lib,
    pkgs,
    ...
  }: {
    imports = [../default.nix];

    virtualisation.vlans = [1];

    networking = {
      useNetworkd = true;
      nftables.enable = true;
      interfaces.eth1 = {
        ipv4.addresses = lib.mkForce [
          {
            address = "192.168.1.${toString ids.${name}}";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = lib.mkForce [
          {
            address = "2001:db8:1::${toString ids.${name}}";
            prefixLength = 64;
          }
        ];
      };
    };

    environment.systemPackages = [pkgs.wireguard-tools];

    services.radii = {
      enable = true;
      settings = {
        inherit site;
        self = name;
      };
      # Hosts give the key encrypted for themselves; a test VM has no host
      # key before it boots, so the throwaway key goes in as plain text.
      privateKey = "set as plain text below";
      watchdog.interval = 5;
    };

    systemd.services.systemd-networkd.serviceConfig = {
      SetCredentialEncrypted = lib.mkForce [];
      SetCredential = ["radii.private-key:${keys.${name}.private}"];
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "radii-overlay";

    node.specialArgs = {inherit lib;};

    nodes = lib.genAttrs (builtins.attrNames site) node;

    testScript = ''
      import json


      def handshook(machine, interface: str) -> None:
          """Waits until the tunnel has had a handshake."""
          machine.wait_until_succeeds(
              f"wg show {interface} latest-handshakes | awk '$2 > 0 {{ found = 1 }} END {{ exit !found }}'",
              timeout=240,
          )


      def endpoint(machine, interface: str) -> str:
          return machine.succeed(f"wg show {interface} endpoints").split()[1]


      def counter(machine, name: str) -> int:
          listing = json.loads(machine.succeed(f"nft --json list counter inet radii {name}"))
          return next(item["counter"]["packets"] for item in listing["nftables"] if "counter" in item)


      def route_device(machine, destination: str) -> str:
          return machine.succeed(f"ip -6 route get {destination}").split(" dev ")[1].split()[0]


      start_all()

      for machine in (hub1, hub2, spoke1, spoke2):
          machine.wait_for_unit("systemd-networkd.service")
          machine.wait_for_unit("babeld.service")

      with subtest("the watchdog moves a tunnel past a dead endpoint"):
          handshook(spoke1, "rd-hub1")
          assert not endpoint(spoke1, "rd-hub1").startswith("[2001:db8:1::99]"), "still on the dead endpoint"
          spoke1.succeed("journalctl -u radii-watchdog | grep -q 'rd-hub1: no handshake yet, trying'")

      with subtest("an IPv4-only spoke uses IPv4 endpoints only"):
          for interface in ("rd-hub1", "rd-hub2"):
              handshook(spoke2, interface)
              assert endpoint(spoke2, interface).startswith("192.168.1."), endpoint(spoke2, interface)

      with subtest("spokes reach each other through a hub"):
          spoke1.wait_until_succeeds("ping -c1 -W2 fd00:d::4", timeout=180)
          spoke2.wait_until_succeeds("ping -c1 -W2 fd00:c::3", timeout=180)
          spoke1.wait_until_succeeds("ping -c1 -W2 fd00:a::1", timeout=180)
          spoke1.wait_until_succeeds("ping -c1 -W2 fd00:b::1", timeout=180)

      with subtest("a spoke's forged source is dropped at the hub"):
          spoke1.succeed("ip -6 address add fd00:d::99/128 dev lo")
          spoke1.fail("ping -c2 -W2 -I fd00:d::99 fd00:a::1")
          spoke1.succeed("ip -6 address del fd00:d::99/128 dev lo")

      with subtest("a source the site does not route is dropped from a hub's tunnel"):
          hub2.wait_until_succeeds("ping -c1 -W2 fd00:a::1", timeout=180)
          assert route_device(hub2, "fd00:a::1") == "rd-hub1", "hub2 does not reach hub1 directly"
          before = counter(hub1, "forged-on-tunnel")
          hub2.succeed("ip -6 address add 2001:db8:ffff::1/128 dev lo")
          hub2.fail("ping -c2 -W2 -I 2001:db8:ffff::1 fd00:a::1")
          hub2.succeed("ip -6 address del 2001:db8:ffff::1/128 dev lo")
          assert counter(hub1, "forged-on-tunnel") > before, "hub1 did not count the forged packets"

      with subtest("a host's own networks are dropped from the uplink"):
          before = counter(hub1, "own-network-from-outside")
          spoke1.succeed("ip -6 address add fd00:a::99/128 dev lo")
          spoke1.succeed("ip -6 route add fd00:a::1/128 via 2001:db8:1::1 dev eth1")
          spoke1.fail("ping -c2 -W2 -I fd00:a::99 fd00:a::1")
          spoke1.succeed("ip -6 route del fd00:a::1/128 via 2001:db8:1::1 dev eth1")
          spoke1.succeed("ip -6 address del fd00:a::99/128 dev lo")
          assert counter(hub1, "own-network-from-outside") > before, "hub1 did not count the forged packets"

      with subtest("traffic moves to the other hub when one fails"):
          spoke1.succeed("ping -c1 -W2 fd00:d::4")
          used = route_device(spoke1, "fd00:d::4")
          failed, other = (hub1, "rd-hub2") if used == "rd-hub1" else (hub2, "rd-hub1")
          failed.crash()
          spoke1.wait_until_succeeds("ping -c1 -W2 fd00:d::4", timeout=240)
          assert route_device(spoke1, "fd00:d::4") == other, "traffic did not move to the other hub"
    '';
  }
