# RADII SITE CHECK
# ----------------
# The whole site table, checked once for every host: what each host's
# assertions check for itself (it is in the table, reaches a hub, its ports
# are valid), plus what only the table as a whole shows (unique ids, host
# addresses and public keys, owned networks that do not overlap, hubs with
# a base port, devices without endpoints). Runs whether or not radii is
# enabled anywhere.
{
  pkgs,
  lib,
  site,
}: let
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) concatMap foldr unique;
  inherit (lib.strings) concatStringsSep;

  radii = import ../_module/lib {inherit lib;};

  # The table typed by the module's own options, so the check sees exactly
  # what hosts see. The stubs stand in for the NixOS options the module
  # reads or defines.
  typed =
    (lib.evalModules {
      specialArgs = {inherit lib pkgs;};
      modules = [
        ../default.nix
        # The module also defines NixOS options (systemd, babeld, the
        # firewall) that no stub declares; radii is off here, so they are
        # ignored. Typos in the site table are still caught by its own types.
        {_module.check = false;}
        ({lib, ...}: let
          inherit (lib.options) mkOption;
          inherit (lib.types) listOf str unspecified;
        in {
          options = {
            assertions = mkOption {
              type = listOf unspecified;
              default = [];
            };
            warnings = mkOption {
              type = listOf str;
              default = [];
            };
            networking.hostName = mkOption {
              type = str;
              default = "";
            };
          };

          config.services.radii.settings.site = site;
        })
      ];
    }).config.services.radii.settings.site;

  # Every host's own view: NixOS hosts and devices alike, so a device that
  # reaches no hub is caught before its tunnel is set up by hand.
  hosts = map (name: radii.checkHost typed name // {inherit name;}) (attrNames typed);

  # A problem with a hub shows in the view of every host that uses it.
  errors = unique (radii.checkSite typed ++ concatMap (host: host.errors) hosts);

  warnings = unique (concatMap (host: host.warnings) hosts);
in
  if errors != []
  then throw (concatStringsSep "\n" (["radii: the site table has problems:"] ++ map (error: "  ${error}") errors))
  else
    foldr (warning: lib.warn "radii: ${warning}")
    (pkgs.runCommand "radii-site" {} "touch $out")
    warnings
