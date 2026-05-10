{config, ...}: {
  services.coturn = {
    enable = false;

    listening-port = 3478;

    realm = "turn.xmpp.ueuie.dev";
    use-auth-secret = true;
    static-auth-secret-file = "/etc/secrets/coturn.auth.txt";
  };

  networking.firewall = {
    allowedTCPPorts = [
      3478
      3479
      5349
      5350
    ];
    allowedUDPPorts = [
      3478
      3479
      5349
      5350
    ];
    allowedUDPPortRanges = [
      {
        from = 49152;
        to = 65535;
      }
    ];
  };
}
