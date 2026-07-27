{
  sigil,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  networking.hostName = mkDefault sigil.self.mid;

  networking = {
    useNetworkd = true;
    useDHCP = false;
    useHostResolvConf = false;
  };
}
