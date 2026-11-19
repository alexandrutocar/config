{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA;
in {
  systemd = {
    services = {
      tinyproxy = {
        wants = [config.services.ssh-dynamic-forward.tunnels.bonnet.serviceName];
        after = [config.services.ssh-dynamic-forward.tunnels.bonnet.serviceName];
      };
    };
  };

  services = {
    tinyproxy = {
      enable = true;

      settings = {
        Listen = sigil.self |> getULA |> ip.toCompressed;

        Port = 8888;

        Allow = [
          (sigil.containers.intra.e079b57e-4727-4408-8c33-39abaae975d9 |> getULA |> ip.toCompressed)
        ];

        ConnectPort = [
          443 # HTTPS
        ];

        Upstream = [
          ''socks5 localhost:1080 ".uni-bonn.de"''
        ];
      };
    };
  };
}
