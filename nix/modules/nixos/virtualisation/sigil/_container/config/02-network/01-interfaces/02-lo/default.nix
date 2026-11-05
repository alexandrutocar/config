{
  sigil,
  lib,
  ...
}: let
  inherit (lib.lists) optional;
in let
  loopback = [
    "::1/128"
  ];
in {
  systemd = {
    network = {
      networks = {
        "10-lo" = {
          matchConfig = {
            Name = "lo";
          };
          address =
            loopback
            ++ optional (sigil.self.addresses.gua != null) "${sigil.self.addresses.gua}/128"
            ++ optional (sigil.self.addresses.ula != null) "${sigil.self.addresses.ula}/128";
        };
      };
    };
  };
}
