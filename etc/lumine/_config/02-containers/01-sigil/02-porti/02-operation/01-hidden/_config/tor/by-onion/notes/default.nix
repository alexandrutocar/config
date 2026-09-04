_: {
  services.tor.relay.onionServices = {
    notes = {
      version = 3;
      map = [
        {
          port = 80;

          target = {
            addr = "[::1]";
            port = 80;
          };
        }
      ];
    };
  };
}
