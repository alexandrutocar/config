# RADII: ENDPOINT WATCHDOG
# ------------------------
# The watchdog's timer and what it leaves alone; overlay.nix covers the move
# past a dead endpoint, networkd-babel.nix the routes to devices. Covers:
#   - the watchdog runs every watchdog.interval, not on systemd's default
#     one-minute timer accuracy
#   - a tunnel a spoke keeps down by hand is left alone: no endpoint moves,
#     nothing logged
#   - once that tunnel is brought up, the watchdog moves it past a dead
#     endpoint
#   - when a link becomes routable, networkd-dispatcher runs the watchdog,
#     which moves a tunnel off an endpoint the spoke has lost its route to
#     at once, though the tunnel is not stale
#   - a working tunnel stays where it is once that route is back
#
# One hub, whose first endpoint answers nobody, and one dual-stack spoke that
# brings its tunnel up by hand (as the `units` option's description shows).
{
  pkgs,
  lib,
}: let
  inherit (lib.attrsets) genAttrs;
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

  # The underlay: every machine on vlan 1, as 192.168.1.<id> and
  # 2001:db8:1::<id>.
  ids = {
    hub = 1;
    spoke = 2;
  };

  # Seconds between the watchdog's runs: well under a minute, so a timer
  # left at systemd's default accuracy shows.
  interval = 5;

  site = {
    # Its first endpoint answers nobody: the spoke's tunnel starts there. Its
    # last one is the way in over IPv4.
    hub = {
      id = ids.hub;
      hostAddress = "fd00:a::1";
      prefix = "fd00:a::/48";
      publicKey = keys.hub.public;
      availableNetworks = ["::/0"];
      endpoints = ["2001:db8:1::99" "2001:db8:1::1" "192.168.1.1"];
      basePort = 51820;
      openPorts = [51822];
    };

    spoke = {
      id = ids.spoke;
      hostAddress = "fd00:b::2";
      prefix = "fd00:b::/48";
      publicKey = keys.spoke.public;
      availableNetworks = ["0.0.0.0/0" "::/0"];
    };
  };

  node = name: extra: {pkgs, ...}: {
    imports = [../default.nix extra];

    virtualisation.vlans = [1];

    networking = {
      useNetworkd = true;
      nftables.enable = true;
      interfaces.eth1 = {
        ipv4.addresses = mkForce [
          {
            address = "192.168.1.${toString ids.${name}}";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = mkForce [
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
      watchdog.interval = interval;
    };

    systemd.services.systemd-networkd.serviceConfig = {
      SetCredentialEncrypted = mkForce [];
      SetCredential = ["radii.private-key:${keys.${name}.private}"];
    };
  };

  # The spoke brings its tunnels up only by hand. A plain value: NixOS
  # checks networkd's [Link] settings before mkDefault or mkIf are resolved.
  byHand = {config, ...}: {
    systemd.network.networks =
      genAttrs config.services.radii.units.networks
      (_: {linkConfig.ActivationPolicy = "manual";});
  };
in
  pkgs.testers.runNixOSTest {
    name = "radii-watchdog";

    node.specialArgs = {inherit lib;};

    nodes = {
      hub = node "hub" {};
      spoke = node "spoke" byHand;
    };

    testScript = ''
      from datetime import timedelta

      INTERVAL = ${toString interval}
      DEAD = "[2001:db8:1::99]"
      LONG = timedelta(seconds=240)


      def runs(machine) -> int:
          """How often the watchdog has finished so far."""
          return int(machine.succeed("journalctl -u radii-watchdog.service --no-pager -o cat | grep -c 'Finished radii endpoint watchdog' || true"))


      def wait_for_runs(machine, count: int) -> None:
          machine.wait_until_succeeds(
              f"test $(journalctl -u radii-watchdog.service --no-pager -o cat | grep -c 'Finished radii endpoint watchdog') -ge {count}",
              timeout=LONG,
          )


      def moves(machine) -> str:
          """The watchdog's own lines: one for every endpoint it moves a tunnel to."""
          return machine.succeed("journalctl -u radii-watchdog.service --no-pager -o cat | grep ', trying ' || true")


      def endpoint(machine, interface: str) -> str:
          return machine.succeed(f"wg show {interface} endpoints").split()[1]


      def is_up(machine, interface: str) -> bool:
          return machine.succeed(f"ip -o link show dev {interface} up").strip() != ""


      start_all()

      for machine in (hub, spoke):
          machine.wait_for_unit("systemd-networkd.service")
          machine.wait_for_unit("radii-watchdog.timer")

      with subtest("the watchdog runs every watchdog.interval"):
          # The first run comes a minute after boot.
          wait_for_runs(hub, 1)
          before = runs(hub)
          hub.sleep(60)
          count = runs(hub) - before
          # Twelve fit into a minute; a timer with systemd's default
          # accuracy of one minute manages a few.
          assert count >= 8, f"the watchdog ran {count} times in 60 s, with an interval of {INTERVAL} s"

      with subtest("a tunnel kept down by hand is left alone"):
          spoke.wait_until_succeeds("test -e /sys/class/net/rd-hub", timeout=LONG)
          assert not is_up(spoke, "rd-hub"), "rd-hub came up by itself, though its policy is manual"
          wait_for_runs(spoke, 3)
          assert not is_up(spoke, "rd-hub"), "rd-hub came up by itself, though its policy is manual"
          assert moves(spoke) == "", f"the watchdog moved a tunnel that is down:\n{moves(spoke)}"
          assert endpoint(spoke, "rd-hub").startswith(DEAD), f"rd-hub left its first endpoint while down: {endpoint(spoke, 'rd-hub')}"

      with subtest("brought up, the tunnel is moved past the dead endpoint"):
          spoke.succeed("networkctl up rd-hub")
          spoke.wait_until_succeeds(
              "wg show rd-hub latest-handshakes | awk '$2 > 0 { found = 1 } END { exit !found }'",
              timeout=LONG,
          )
          assert not endpoint(spoke, "rd-hub").startswith(DEAD), "still on the dead endpoint"
          assert "rd-hub: no handshake yet, trying" in moves(spoke), f"the watchdog did not report the move:\n{moves(spoke)}"
          spoke.wait_until_succeeds("ping -c1 -W2 fd00:a::1", timeout=LONG)

      with subtest("a link becoming routable moves a tunnel off an endpoint without a route"):
          assert endpoint(spoke, "rd-hub").startswith("[2001:db8:1::1]"), f"rd-hub is not on the hub's IPv6 endpoint: {endpoint(spoke, 'rd-hub')}"
          # From here on only networkd-dispatcher runs the watchdog.
          spoke.succeed("systemctl stop radii-watchdog.timer")
          # The spoke loses its IPv6 route to the hub, as on an IPv4-only
          # network. The tunnel's handshake is recent, so it is not stale:
          # only the route check can move it.
          spoke.succeed("ip -6 route add unreachable 2001:db8:1::/64 metric 1")
          spoke.succeed("networkctl down eth1")
          spoke.succeed("networkctl up eth1")
          spoke.wait_until_succeeds("wg show rd-hub endpoints | grep -qF '192.168.1.1:'", timeout=timedelta(seconds=60))
          assert "rd-hub: no route to [2001:db8:1::1]" in moves(spoke), f"the watchdog did not report the move:\n{moves(spoke)}"
          spoke.wait_until_succeeds("ping -c1 -W2 fd00:a::1", timeout=LONG)

      with subtest("a working tunnel stays where it is once the route is back"):
          spoke.succeed("ip -6 route del unreachable 2001:db8:1::/64 metric 1")
          spoke.succeed("systemctl start radii-watchdog.timer")
          wait_for_runs(spoke, runs(spoke) + 3)
          assert endpoint(spoke, "rd-hub").startswith("192.168.1.1:"), f"rd-hub left a working endpoint: {endpoint(spoke, 'rd-hub')}"
    '';
  }
