# RADII: NETWORKD AND BABELD
# --------------------------
# Where systemd-networkd and babeld meet: babeld installs routes over links
# networkd owns, into the table networkd's rules point at, and announces
# routes that networkd and the watchdog put in main. Covers what goes wrong
# when one of them changes things under the other:
#   - routeTable only takes tables babeld can address (checked at evaluation,
#     from the option's type)
#   - babeld uses every tunnel, though it starts before they have addresses
#   - babel routes land in routeTable and nowhere else
#   - overlay routes win over main's default route, main's more specific
#     routes win over the overlay
#   - restarting, reloading or reconfiguring networkd keeps babel's routes
#     and radii's rules
#   - a tunnel brought down and up gets its routes back
#   - a hub brings a downed tunnel back up by itself
#   - babeld follows a tunnel networkd recreates with a new interface index
#   - stopping babeld leaves no routes behind, starting it brings them back
#   - while babeld has no routes, the site is unreachable instead of
#     following main's default route out of the uplink
#   - the /48 goes with networkd's route and comes back when networkd
#     restores it
#   - a device's route from the watchdog is announced and survives a
#     networkd restart
#   - a stale device's route is withdrawn
#
# One hub, one spoke and a phone (a device, running wg-quick from the file
# radii generates for it). Failover between hubs is overlay.nix's job.
{
  pkgs,
  lib,
}: let
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
    phone = {
      private = "yMWIYYazxiq3wPo9BL4cEIwgnz6++ODj+5d3s/DDy1Q=";
      public = "SRMO23MjldNrfhDJ9x5HftNbRtUAyq240zN3kJWyL2c=";
    };
  };

  # The underlay: every machine on vlan 1, as 2001:db8:1::<id>.
  ids = {
    hub = 1;
    spoke = 2;
    phone = 3;
  };

  # Not the module's default, so routes that ignore the option show.
  routeTable = 200;

  site = {
    hub = {
      id = ids.hub;
      hostAddress = "fd00:a::1";
      prefix = "fd00:a::/48";
      publicKey = keys.hub.public;
      availableNetworks = ["::/0"];
      endpoints = ["2001:db8:1::1"];
      basePort = 51820;
      openPorts = [
        {
          from = 51822;
          to = 51823;
        }
      ];
    };

    spoke = {
      id = ids.spoke;
      hostAddress = "fd00:b::2";
      prefix = "fd00:b::/48";
      publicKey = keys.spoke.public;
      availableNetworks = ["::/0"];
    };

    phone = {
      id = ids.phone;
      kind = "device";
      hostAddress = "fd00:c::3";
      publicKey = keys.phone.public;
      availableNetworks = ["::/0"];
    };
  };

  # ROUTE TABLE LIMIT
  # -----------------
  # babeld puts the table number into one byte and silently wraps larger
  # ones (6696 lands in table 40), so the option must refuse them. 253 to
  # 255 are the kernel's own. Asks the option's type directly: reading
  # `config` would need every option the module defines (systemd, babeld,
  # the firewall), which only a whole NixOS evaluation declares.
  routeTableType =
    (lib.evalModules {
      specialArgs = {inherit lib pkgs;};
      modules = [
        ../default.nix
        # The module's other definitions have no options here: ignore them.
        {_module.check = false;}
      ];
    }).options.services.radii.routeTable.type;

  wrongTables =
    builtins.filter (table: !(routeTableType.check table)) [1 252]
    ++ builtins.filter routeTableType.check [0 253 6696];

  # NODES
  # -----
  underlay = name: {
    virtualisation.vlans = [1];

    networking.interfaces.eth1.ipv6.addresses = mkForce [
      {
        address = "2001:db8:1::${toString ids.${name}}";
        prefixLength = 64;
      }
    ];
  };

  radiiNode = name: {pkgs, ...}: {
    imports = [../default.nix (underlay name)];

    networking = {
      useNetworkd = true;
      nftables.enable = true;
    };

    environment.systemPackages = [pkgs.wireguard-tools pkgs.socat];

    # Lets the test read babeld's interfaces and routes (read-only, on ::1).
    services.babeld.extraConfig = "local-port 33123";

    services.radii = {
      enable = true;
      settings = {
        inherit site;
        self = name;
      };
      inherit routeTable;
      # Hosts give the key encrypted for themselves; a test VM has no host
      # key before it boots, so the throwaway key goes in as plain text.
      privateKey = "set as plain text below";
      watchdog.interval = 5;
    };

    systemd.services.systemd-networkd.serviceConfig = {
      SetCredentialEncrypted = mkForce [];
      SetCredential = ["radii.private-key:${keys.${name}.private}"];
    };
  };

  # The phone runs no radii: the module only derives its WireGuard file, the
  # one the real device gets (`wg.<hub>-<n>.file`), and wg-quick brings it
  # up with the key filled in.
  phoneNode = {
    config,
    pkgs,
    ...
  }: let
    tunnel = config.services.radii.derived.hosts.phone.wg."hub-1";
  in {
    imports = [../default.nix (underlay "phone")];

    services.radii.settings.site = site;

    networking.wg-quick.interfaces.wg0.configFile = toString (
      pkgs.runCommand "phone-hub.conf" {} ''
        sed 's|<private key>|${keys.phone.private}|' ${tunnel.file} > $out
      ''
    );

    environment.systemPackages = [pkgs.wireguard-tools];
  };
in
  if wrongTables != []
  then throw "radii: services.radii.routeTable must take 1 to 252 only (babeld wraps larger tables, and 253 to 255 are the kernel's), but gets ${toString wrongTables} wrong"
  else
    pkgs.testers.runNixOSTest {
      name = "radii-networkd-babel";

      node.specialArgs = {inherit lib;};

      nodes = {
        hub = radiiNode "hub";
        spoke = radiiNode "spoke";
        phone = phoneNode;
      };

      testScript = ''
        from contextlib import contextmanager
        from datetime import timedelta

        TABLE = "${toString routeTable}"
        SHORT = timedelta(seconds=30)
        MEDIUM = timedelta(seconds=120)
        LONG = timedelta(seconds=240)


        def route(prefix: str, table: str = TABLE, proto: str = "babel") -> str:
            """A shell test: whether `table` has a route to `prefix` of `proto`, as ip prints it (a /128 without its length)."""
            return f"ip -6 route show table {table} proto {proto} | grep -q '^{prefix} '"


        def route_device(machine, destination: str) -> str:
            return machine.succeed(f"ip -6 route get {destination}").split(" dev ")[1].split()[0]


        def babel_dump(machine) -> str:
            return machine.succeed("echo dump | socat -t2 - TCP6:[::1]:33123")


        def overlay_up(timeout: timedelta = LONG) -> None:
            """Waits until hub and spoke reach each other's host addresses through the overlay."""
            spoke.wait_until_succeeds("ping -c1 -W2 fd00:a::1", timeout=timeout)
            hub.wait_until_succeeds("ping -c1 -W2 fd00:b::2", timeout=timeout)


        def diagnose() -> None:
            """Prints every machine's state, for when a check fails."""
            hosts = [
                "wg show all latest-handshakes",
                "wg show all endpoints",
                "ip -6 address show",
                "ip -6 rule show",
                "ip -6 route show table all",
                "echo dump | socat -t2 - TCP6:[::1]:33123",
                "journalctl -u babeld --no-pager | tail -n 30",
                "journalctl -u systemd-networkd --no-pager | tail -n 30",
                "journalctl -u radii-watchdog --no-pager | grep -v systemd | tail -n 20",
            ]
            device = ["wg show all", "ip -6 address show", "ip -6 route show table all"]
            for machine, commands in ((hub, hosts), (spoke, hosts), (phone, device)):
                for command in commands:
                    status, output = machine.execute(command)
                    print(f"=== {machine.name}: {command} (exit {status})\n{output}")


        @contextmanager
        def check(name: str):
            """A subtest that dumps every machine's state when it fails."""
            with subtest(name):
                try:
                    yield
                except Exception:
                    diagnose()
                    raise


        start_all()

        for machine in (hub, spoke):
            machine.wait_for_unit("systemd-networkd.service")
            machine.wait_for_unit("babeld.service")
        phone.wait_for_unit("wg-quick-wg0.service")

        with check("babeld uses every tunnel, though it starts before they have addresses"):
            overlay_up()
            for machine, interface in ((hub, "rd-spoke"), (spoke, "rd-hub")):
                dump = babel_dump(machine)
                assert f"add interface {interface} up true ipv6 fe80::" in dump, dump
            # Devices run no babel: babeld leaves their tunnels alone.
            assert "rd-phone" not in babel_dump(hub), "babeld runs on the phone's tunnel"

        with check("babel routes land in the route table and nowhere else"):
            spoke.wait_until_succeeds(route("fd00:a::/48"), timeout=SHORT)
            hub.wait_until_succeeds(route("fd00:b::/48"), timeout=SHORT)
            for machine in (hub, spoke):
                lines = machine.succeed("ip -6 route show table all proto babel").splitlines()
                stray = [line for line in lines if f" table {TABLE} " not in line]
                assert lines and not stray, f"{machine.name}: babel routes outside table {TABLE}: {stray}"

        def through_overlay(machine, destination: str, setting: str) -> None:
            """Asserts that `destination` is routed through the tunnel to the hub, with ip's answer if not."""
            answer = machine.succeed(f"ip -6 route get {destination}")
            assert " dev rd-hub " in answer, f"{setting}: {destination} left the overlay:\n{answer}"


        def unreachable(machine, destination: str, setting: str) -> None:
            """Asserts that `destination` has no route at all: ip fails, or names an unreachable route."""
            status, answer = machine.execute(f"ip -6 route get {destination} 2>&1")
            assert status != 0 or "unreachable" in answer, f"{setting}: {machine.name} still routes {destination}:\n{answer}"


        with check("overlay routes win over main's default route, main's more specific routes win over the overlay"):
            # Hosts have a default route in main, as these VMs do through eth0
            # (from a router advertisement). Each step checks the hub's
            # address and another one in its /48 (fd00:a:0::/48: the third group
            # is part of the prefix, so fd00:a:2:: would be someone else's).
            for destination in ("fd00:a::1", "fd00:a:0:2::1"):
                through_overlay(spoke, destination, "with the VM's default route")

            spoke.succeed("ip -6 route add default via 2001:db8:1::99 dev eth1 metric 1")
            for destination in ("fd00:a::1", "fd00:a:0:2::1"):
                through_overlay(spoke, destination, "with a preferred default route in main")
            spoke.succeed("ip -6 route del default via 2001:db8:1::99 dev eth1 metric 1")

            # A route in main inside a peer's /48, as a local container's would be.
            spoke.succeed("ip -6 route add unreachable fd00:a:0:1::/64")
            spoke.fail("ip -6 route get fd00:a:0:1::1")
            for destination in ("fd00:a::1", "fd00:a:0:2::1"):
                through_overlay(spoke, destination, "with an unreachable /64 in main")
            spoke.succeed("ip -6 route del unreachable fd00:a:0:1::/64")

        with check("restarting, reloading or reconfiguring networkd keeps babel's routes and radii's rules"):
            for machine, prefix, interface in ((spoke, "fd00:a::/48", "rd-hub"), (hub, "fd00:b::/48", "rd-spoke")):
                for action in ("systemctl restart systemd-networkd", "networkctl reload", f"networkctl reconfigure {interface}"):
                    machine.succeed(action)
                    machine.wait_for_unit("systemd-networkd.service")
                    # Waits only briefly: a route that is gone for longer
                    # breaks traffic, even if it comes back later.
                    machine.wait_until_succeeds(route(prefix), timeout=SHORT)
                    rules = machine.succeed("ip -6 rule show")
                    assert rules.count(f"lookup {TABLE}") == 1 and rules.count("suppress_prefixlength 0") == 1, f"{machine.name} after {action}:\n{rules}"
                overlay_up(MEDIUM)

        with check("a tunnel brought down and up gets its routes back"):
            spoke.succeed("networkctl down rd-hub")
            spoke.wait_until_fails(route("fd00:a::/48"), timeout=SHORT)
            spoke.succeed("networkctl up rd-hub")
            spoke.wait_until_succeeds(route("fd00:a::/48"), timeout=MEDIUM)
            overlay_up(MEDIUM)

        with check("a hub brings a downed tunnel back up by itself"):
            hub.succeed("ip link set rd-spoke down")
            hub.wait_until_succeeds("ip link show rd-spoke | grep -q '[<,]UP[,>]'", timeout=SHORT)
            overlay_up(MEDIUM)

        with check("babeld follows a tunnel networkd recreates with a new interface index"):
            index = spoke.succeed("cat /sys/class/net/rd-hub/ifindex").strip()
            spoke.succeed("ip link del rd-hub")
            spoke.wait_until_fails(route("fd00:a::/48"), timeout=SHORT)
            spoke.succeed("systemctl restart systemd-networkd")
            spoke.wait_until_succeeds("test -e /sys/class/net/rd-hub", timeout=SHORT)
            assert spoke.succeed("cat /sys/class/net/rd-hub/ifindex").strip() != index, "rd-hub kept its index"
            overlay_up()
            assert "add interface rd-hub up true ipv6 fe80::" in babel_dump(spoke), "babeld lost rd-hub"

        with check("stopping babeld leaves no routes behind, starting it brings them back"):
            spoke.succeed("systemctl stop babeld.service")
            spoke.succeed('test -z "$(ip -6 route show table all proto babel)"')
            # The site's networks (the hub's address, its /48, the phone)
            # must not fall through to main's default route, which these VMs
            # have through eth0: that would send them out unencrypted.
            for destination in ("fd00:a::1", "fd00:a:0:2::1", "fd00:c::3"):
                unreachable(spoke, destination, "with babeld stopped")
            # The hub drops the spoke's routes once the spoke goes silent.
            hub.wait_until_fails(route("fd00:b::/48"), timeout=MEDIUM)
            spoke.succeed("systemctl start babeld.service")
            overlay_up()

        with check("the /48 goes with networkd's route and comes back when networkd restores it"):
            spoke.succeed("ip -6 route del fd00:b::/48 dev radii proto static")
            hub.wait_until_fails(route("fd00:b::/48"), timeout=MEDIUM)
            spoke.succeed("networkctl reconfigure radii")
            spoke.wait_until_succeeds(route("fd00:b::/48", table="main", proto="static"), timeout=SHORT)
            hub.wait_until_succeeds(route("fd00:b::/48"), timeout=MEDIUM)
            overlay_up()

        with check("a device's route from the watchdog is announced and survives a networkd restart"):
            hub.wait_until_succeeds(route("fd00:c::3", table="main", proto="200"), timeout=LONG)
            spoke.wait_until_succeeds(route("fd00:c::3"), timeout=MEDIUM)
            spoke.wait_until_succeeds("ping -c1 -W2 fd00:c::3", timeout=MEDIUM)
            hub.succeed("systemctl restart systemd-networkd")
            hub.wait_for_unit("systemd-networkd.service")
            spoke.wait_until_succeeds(route("fd00:c::3"), timeout=SHORT)
            spoke.wait_until_succeeds("ping -c1 -W2 fd00:c::3", timeout=SHORT)

        with check("a stale device's route is withdrawn"):
            phone.succeed("systemctl stop wg-quick-wg0.service")
            # After watchdog.staleAfter (180 s by default) without a handshake.
            hub.wait_until_fails(route("fd00:c::3", table="main", proto="200"), timeout=timedelta(seconds=300))
            spoke.wait_until_fails(route("fd00:c::3"), timeout=MEDIUM)
      '';
    }
