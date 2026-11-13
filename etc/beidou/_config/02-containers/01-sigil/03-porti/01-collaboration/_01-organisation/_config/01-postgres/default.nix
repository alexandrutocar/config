{
  config,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) ranges toCIDR;
  inherit (lib.extra.ip.network) getFirstHost;
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
      loopback = (builtins.head ranges.ipv6.loopback) |> getFirstHost |> toCIDR;
    in ''
      host  stalwart stalwart ${(networks.aether.internal.net._meta.network |> toCIDR)} trust
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
