{lib, ...}: {
  config = let
    inherit (lib.modules) mkDefault;
  in {
    system.stateVersion = mkDefault "26.05";
  };
}
