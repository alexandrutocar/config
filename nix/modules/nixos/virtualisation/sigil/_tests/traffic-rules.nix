# SIGIL TRAFFIC RULES
# -------------------
# One host VM running three sigil containers with enforcement on, and an
# outside VM standing in for the internet. Covers what cannot be tried on live
# hosts before the switch:
#   - a declared flow passes, through the host and the container firewall
#   - an undeclared port and an undeclared source are dropped by the host
#   - the container firewall drops what the host never sees (host-originated)
#   - forged sources are dropped, from a container's veth and from outside
#   - an internet rule reaches only its GUA extra, not the container's own GUA
#
# The sigil host is a QEMU VM, not an nspawn test container: sigil runs nspawn
# containers itself (user namespaces, idmapped store), which does not nest
# inside an nspawn test machine in the build sandbox.
{
  pkgs,
  lib,
  self,
}: let
  # Container identities: valid UUIDs, as sigil requires.
  mids = {
    server = "11111111-1111-4111-8111-111111111111"; # HTTP on 8080 (declared) and 8081 (not)
    client = "22222222-2222-4222-8222-222222222222"; # the declared source
    public = "33333333-3333-4333-8333-333333333333"; # HTTP on 80, public through a GUA extra only
  };

  group = "test";

  # A plain HTTP server on every address of the container.
  httpServer = port: {pkgs, ...}: {
    systemd.services."http-${toString port}" = {
      wantedBy = ["multi-user.target"];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString port} --bind :: --directory ${pkgs.writeTextDir "index.html" "ok"}";
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "sigil-traffic-rules";

    node.specialArgs = {inherit lib self;};

    nodes = {
      host = {
        config,
        lib,
        pkgs,
        ...
      }: let
        containers = config.services.sigil.settings.containers.${group};
        ula = mid: containers.${mid}.addresses.ipv6.ula;
        hostAddress = "fd00:1:2::1";
      in {
        imports = [../default.nix];

        virtualisation = {
          vlans = [1];
          memorySize = 3072;
        };

        networking = {
          useNetworkd = true;
          nftables.enable = true;
          interfaces.eth1.ipv6.addresses = lib.mkForce [
            {
              address = "2001:db8:ffff::1";
              prefixLength = 64;
            }
          ];
        };

        # sigil does not assign the host address; routes prefer it as source,
        # so it must exist. Production hosts carry it on the overlay.
        systemd.network.networks."05-lo" = {
          matchConfig.Name = "lo";
          address = ["127.0.0.1/8" "::1/128" "${hostAddress}/128"];
        };

        # The test VM's store is a shared filesystem without idmapped mounts;
        # the store is world-readable, so a plain bind serves the containers.
        systemd.nspawn = lib.genAttrs (builtins.attrValues mids) (_: {
          settings.Files.BindReadOnly = lib.mkForce ["/nix/store"];
        });

        environment.systemPackages = [pkgs.curl];

        services.sigil = {
          enable = true;

          settings = {
            network = {
              ula.prefix = "fd00:1:2::/48";
              gua.prefix = "2001:db8:1:2::/64";
              inherit hostAddress;
            };

            containers.${group} = {
              ${mids.server} = {
                modules = [(httpServer 8080) (httpServer 8081)];

                # The client and the host itself may reach 8080; 8081 is open
                # in the container but declared nowhere.
                rules.networkTraffic.incoming = [
                  {
                    sourceAddresses = [(ula mids.client) hostAddress];
                    destinationAddresses = [(ula mids.server)];
                    allowedTraffic = [
                      {
                        protocol = "tcp";
                        ports = [8080];
                      }
                    ];
                  }
                ];
              };

              ${mids.client} = {};

              ${mids.public} = {
                modules = [(httpServer 80)];

                addresses.ipv6.extra.gua.web = "::80";

                # Listens on all its addresses; only the extra is public.
                rules.networkTraffic.incoming = [
                  {
                    sourceAddresses = ["::/0"];
                    destinationAddresses = [containers.${mids.public}.addresses.ipv6.extra.gua.web];
                    allowedTraffic = [
                      {
                        protocol = "tcp";
                        ports = [80];
                      }
                    ];
                  }
                ];
              };
            };
          };
        };
      };

      outside = {
        lib,
        pkgs,
        ...
      }: {
        virtualisation.vlans = [1];

        networking.interfaces.eth1.ipv6 = {
          addresses = lib.mkForce [
            {
              address = "2001:db8:ffff::2";
              prefixLength = 64;
            }
          ];
          routes = [
            {
              address = "2001:db8:1:2::";
              prefixLength = 64;
              via = "2001:db8:ffff::1";
            }
            {
              address = "fd00:1:2::";
              prefixLength = 48;
              via = "2001:db8:ffff::1";
            }
          ];
        };

        environment.systemPackages = [pkgs.curl];
      };
    };

    testScript = {nodes, ...}: let
      inherit (lib.extra) ip;
      containers = nodes.host.services.sigil.settings.containers.${group};
      addresses = mid: containers.${mid}.addresses.ipv6;
      text = ip.toCompressed;
    in ''
      import json

      server = "${mids.server}"
      client = "${mids.client}"
      public = "${mids.public}"

      server_ula = "${text (addresses mids.server).ula}"
      client_ula = "${text (addresses mids.client).ula}"
      public_gua = "${text (addresses mids.public).gua}"
      public_web = "${text (addresses mids.public).extra.gua.web}"
      host_address = "${nodes.host.services.sigil.settings.network.hostAddress |> text}"


      def inside(mid: str, command: str) -> str:
          """Runs a host binary in the container's network namespace."""
          return f"nsenter --target $(machinectl show --property=Leader --value {mid}) --net -- {command}"


      def get(url: str, source: str = "") -> str:
          interface = f"--interface {source} " if source else ""
          return f"curl --silent --fail --max-time 5 {interface}{url}"


      def counter(name: str) -> int:
          listing = json.loads(host.succeed(f"nft --json list counter inet sigil {name}"))
          return next(item["counter"]["packets"] for item in listing["nftables"] if "counter" in item)


      start_all()

      for mid in (server, client, public):
          host.wait_for_unit(f"systemd-nspawn@{mid}.service")

      with subtest("a declared flow passes through the host and the container firewall"):
          host.wait_until_succeeds(inside(client, get(f"http://[{server_ula}]:8080/")), timeout=180)

      with subtest("the container firewall accepts the host where a rule names it"):
          host.succeed(get(f"http://[{server_ula}]:8080/", host_address))

      with subtest("an undeclared port is dropped by the host"):
          before = counter("undeclared-incoming")
          host.fail(inside(client, get(f"http://[{server_ula}]:8081/")))
          assert counter("undeclared-incoming") > before, "the host did not count the undeclared port"

      with subtest("an undeclared source is dropped by the host"):
          before = counter("undeclared-incoming")
          host.fail(inside(public, get(f"http://[{server_ula}]:8080/")))
          assert counter("undeclared-incoming") > before, "the host did not count the undeclared source"

      with subtest("the container firewall drops what the host does not forward"):
          before = counter("undeclared-incoming")
          host.fail(get(f"http://[{server_ula}]:8081/", host_address))
          assert counter("undeclared-incoming") == before, "host-originated traffic reached the forward chain"

      with subtest("a forged source on a container's veth is dropped"):
          before = counter("forged-on-veth")
          host.succeed(inside(public, f"ip address add {client_ula}/128 dev lo"))
          host.fail(inside(public, get(f"http://[{server_ula}]:8080/", client_ula)))
          host.succeed(inside(public, f"ip address del {client_ula}/128 dev lo"))
          assert counter("forged-on-veth") > before, "the forged packets were not counted"

      with subtest("a container's address from outside is dropped"):
          before = counter("forged-container-address")
          outside.succeed(f"ip address add {client_ula}/128 dev eth1 nodad")
          outside.fail(get(f"http://[{server_ula}]:8080/", client_ula))
          outside.succeed(f"ip address del {client_ula}/128 dev eth1")
          assert counter("forged-container-address") > before, "the forged packets were not counted"

      with subtest("an internet rule reaches only its GUA extra"):
          outside.wait_until_succeeds(get(f"http://[{public_web}]/"), timeout=60)
          outside.fail(get(f"http://[{public_gua}]/"))
    '';
  }
