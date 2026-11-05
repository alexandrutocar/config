{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.lists) all any elem filter optionals toList;
  inherit (lib.strings) getName;
  inherit (lib.trivial) flip id;
in {
  imports = recursive ./_config;

  # HARDWARE CONFIGURATION
  # -------- -------------
  hardware.facter.reportPath = ./report.json;

  # UNFREE ALLOWLIST
  # ----------------
  nixpkgs.config.allowUnfreePredicate = let
    inherit (config.home-manager.users.alex.programs) obsidian;
    inherit (config.i18n) inputMethod;
  in let
    allowedLicenses = map (l: l.shortName or l) [];

    allowedPackages = map getName (
      optionals obsidian.enable [obsidian.package]
      ++ filter (a: getName a == getName pkgs.fcitx5-black-simplicity) (optionals (inputMethod.enable && inputMethod.type == "fcitx5") inputMethod.fcitx5.addons)
    );
  in let
    isAllowedPackage = pkg: elem (getName pkg) allowedPackages;
    isAllowedLicense = pkg: all (license: (license.free or false) || elem (license.shortName or null) allowedLicenses) (toList (pkg.meta.license or []));
  in
    pkg: any (flip id pkg) [isAllowedPackage isAllowedLicense];
}
