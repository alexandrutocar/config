{container, ...}: let
  inherit (container) self;
in {
  services.anki-sync-server = {
    enable = true;
    
    port = 8080;

    address = self.localAddress;
    users = [
      {
        username = "Alex";
        password = "TWuxx4wigwfMPTRY";
      }
      {
        username = "Mailo";
        password = "rVAHPFCN7Apgqjbw";
      }
    ];
  };
}
