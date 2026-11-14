{lib, ...}: let
  inherit (lib.extra) ip;
in {
  services.tor.relay.onionServices = {
    notes = {
      version = 3;
      map = let
        loopbackAddresses = ip.wellKnown.loopback |> map ip.toURIHost;
      in
        loopbackAddresses
        |> map (
          addr: let
            port = 80;
          in {
            inherit port;

            target = {
              inherit addr port;
            };
          }
        );
    };
  };
}
