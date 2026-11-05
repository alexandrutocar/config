{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.lists) all any elem optionals toList;
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
    inherit (config.services.sigil.settings.containers.intra.d86c8e1c-2bcd-4d2f-a3b2-7962afc28a51.evaluation.config.services) ollama;
    inherit (config.services.sigil.settings.containers.intra.a4205b50-197a-40c8-8057-fe1394630e91.evaluation.config.services) n8n n8n-task-runners;
    inherit (config.hardware) nvidia;
  in let
    allowedLicenses = map (l: l.shortName or l) (
      optionals ollama.enable [lib.licenses.nvidiaCuda lib.licenses.nvidiaCudaRedist]
    );

    allowedPackages = map getName (
      config.boot.extraModulePackages # nvidia-kernel-modules
      ++ optionals nvidia.enabled [nvidia.package]
      ++ optionals n8n.enable [n8n.package]
      ++ optionals n8n-task-runners.enable [n8n-task-runners.launcherPackage]
    );
  in let
    isAllowedPackage = pkg: elem (getName pkg) allowedPackages;
    isAllowedLicense = pkg: all (license: (license.free or false) || elem (license.shortName or null) allowedLicenses) (toList (pkg.meta.license or []));
  in
    pkg: any (flip id pkg) [isAllowedPackage isAllowedLicense];
}
