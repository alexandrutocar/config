{
  config,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra) ip;
  inherit (lib.modules) mkForce;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        config.services.postgresql.settings.port
      ];
    };
  };

  services.postgresql = {
    enable = true;
    settings = {
      listen_addresses = mkForce "*";
    };

    authentication = let
      loopback = (builtins.head ip.ranges.ipv6.loopback) |> ip.network.getFirstHost |> ip.toCIDR;
    in ''
      host  stalwart stalwart ${(networks.aether.internal.net._meta.network |> ip.toCIDR)} trust
      host  stalwart stalwart ${loopback} trust
    '';

    ensureUsers = [
      {
        name = "stalwart";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "stalwart"
    ];
  };
}
