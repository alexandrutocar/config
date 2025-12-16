{
  self,
  lib,
  ...
}: let
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /nix/nixos/modules);

  nixpkgs.overlays = attrValues self.overlays;

  system.stateVersion = "25.11";
}
