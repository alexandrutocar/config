{
  self,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
  inherit (lib.modules) mkForce;
in let
  colleiContainers = shortPathToContainers self.nixosConfigurations.collei.config;
in {
  services.postgresql = {
    enable = true;
    settings = {
      # Who may connect over the network is set where the container is
      # defined: sigil's traffic rules and the matching pg_hba line.
      listen_addresses = mkForce "*";
    };

    authentication = let
      loopback = (builtins.head ip.ranges.ipv6.loopback) |> ip.network.getFirstHost |> ip.toCIDR;
    in
      ''
        host  stalwart stalwart ${loopback} trust
      ''
      + ''
        host  stalwart stalwart ${colleiContainers.porti.c7f4d370-8043-46c8-97ae-39417237ac82 |> getULA |> ip.toCIDR} trust
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
