{
  config,
  lib,
  ...
}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCIDR;
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

    authentication = ''
      host  stalwart stalwart ${(networks.aether.internal.net._meta.network |> toCIDR)} trust
      host  stalwart stalwart ::1/128 trust
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
