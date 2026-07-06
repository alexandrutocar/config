{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.types) attrsOf bool float int listOf nullOr oneOf path plistData str;
in
  {escape ? true}: {
    type = let
      valueType =
        nullOr (oneOf [
          plistData
          bool
          int
          float
          str
          path
          (attrsOf valueType)
          (listOf valueType)
        ])
        // {
          description = "Property list (plist) value";
        };
    in
      valueType;

    generate = name: value: pkgs.writeText name (lib.generators.toPlist {inherit escape;} value);
  }
