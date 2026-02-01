{container, ...}: let
  inherit (container) self;
in {
  services.invidious = {
    enable = true;
    address = self.localAddress;
    port = 8080;
    domain = "invidious.ueuie.dev";
  };
}
