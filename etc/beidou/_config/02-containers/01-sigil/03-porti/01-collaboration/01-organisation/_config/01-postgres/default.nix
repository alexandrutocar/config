{
  config,
  lib,
  ...
}: let
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
      host  stalwart stalwart fda0:9527:68ee::/48 trust
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
