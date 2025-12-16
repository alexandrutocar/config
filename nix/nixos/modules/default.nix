{lib, ...}: let
  inherit (lib.custom.files.list) recursive;
  inherit (lib.lists) flatten;
in {
  imports = flatten (builtins.map recursive [
    ./hardware
    ./services
    ./programs
  ]);
}
