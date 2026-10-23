{
  config,
  sigil,
  ...
}: {
  networking = {
    firewall = {
      allowedTCPPorts = [8888];
    };
  };

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
        Listen = sigil.self.addresses.ula;

        Port = 8888;

        Allow = [
          sigil.containers.intra."e079b57e-4727-4408-8c33-39abaae975d9".addresses.ula
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
