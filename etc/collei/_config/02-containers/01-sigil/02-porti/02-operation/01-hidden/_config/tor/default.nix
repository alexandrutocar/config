_: {
  services.tor = {
    enable = true;
    enableGeoIP = false;

    settings = {
      ClientUseIPv4 = false;
      ClientUseIPv6 = true;
      ClientPreferIPv6ORPort = true;
    };
  };
}
