{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.programs.lite;
in {
  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.strings) literalExpression;

    inherit (lib.custom.types.colors) hex;
    inherit (lib.types) nullOr int str submodule;
  in {
    programs.lite = {
      enable = mkEnableOption "lite";

      package = mkPackageOption pkgs.custom "lite" {};
    };
  };

  config = let
    inherit (lib.custom.colors) hexToBin;
    inherit (lib.lists) singleton;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf;
    inherit (lib.strings) concatStringsSep;
  in
    mkIf cfg.enable {
      home.packages = [cfg.package];
    };
}
