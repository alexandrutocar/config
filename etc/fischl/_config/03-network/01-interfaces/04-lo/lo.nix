{lib, ...}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCIDR;
  inherit (lib.extra.ip.address) singleHostRoute;
in {
  systemd = {
    network = {
      networks = {
        "00-lo" = {
          matchConfig = {
            Name = "lo";
          };
          address =
            [
              "::1/128"
              "127.0.0.1/8"
            ]
            ++ [
              (networks.aether.internal.net.hosts.fischl |> singleHostRoute |> toCIDR)
            ];
        };
      };
    };
  };
}
