{infos, ...}: {
  services.tor = {
    enable = true;

    settings = {
      Nickname = "Aether";
      ContactInfo = "admin@aether.tor.relay.ueuie.earth";
      ORPort = [
        {
          addr = infos.gua.address;
          port = "50000";
        }
      ];
    };
  };
}
