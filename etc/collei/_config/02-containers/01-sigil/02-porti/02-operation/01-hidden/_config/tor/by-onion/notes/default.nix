{lib, ...}: let
  inherit (lib.extra.ip) toURIHost wellKnown;
in {
  services.tor.relay.onionServices = {
    notes = {
      version = 3;
      map = let
        loopbackAddresses = wellKnown.loopback |> map toURIHost;
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
