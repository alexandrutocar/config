{infos, ...}: {
  services.tor = {
    enable = true;

    settings = {
      Nickname = "Beidou";
      ContactInfo = "admin@beidou.tor.relay.ueuie.earth";
      ORPort = [
        {
          addr = infos.gua.address;
          port = "50000";
        }
      ];
    };
  };
}
