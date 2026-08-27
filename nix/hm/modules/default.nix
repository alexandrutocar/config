{lib, ...}: let
  inherit (lib.extra.files.list) recursive;
in {
  imports = recursive ./services ++ recursive ./programs;
}
