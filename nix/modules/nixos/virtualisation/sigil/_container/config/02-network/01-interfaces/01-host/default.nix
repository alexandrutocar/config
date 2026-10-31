_: {
  systemd = {
    network = {
      networks = {
        "10-host0" = {
          networkConfig = {
            IPv6AcceptRA = false;
            IPv6LinkLocalAddressGenerationMode = "none";
          };

          matchConfig = {
            Name = "host0";
          };

          addresses = [
            {
              # fe80::c is at the host0 end on the container side.
              Address = "fe80::c/64";
            }
          ];

          routes = [
            {
              Destination = "::/0";
              # fe80::1 is at the ve- end on the host side.
              Gateway = "fe80::1";
              GatewayOnLink = true;
            }
          ];
        };
      };
    };
  };
}
