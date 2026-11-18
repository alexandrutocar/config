{
  hostName,
  lib,
  ...
}: let
  inherit (lib.alias) addresses radii;
in {
  services.sigil = {
    enable = true;

    settings = {
      network = let
        systemSite = addresses.on-prem.specht;
      in {
        inherit (radii.site.${hostName}) hostAddress;

        enforceTrafficRules = true;

        gua = {
          prefix = systemSite.hosts.${hostName}.managedNetworks.ipv6.gua;
        };

        ula = {
          inherit (radii.site.${hostName}) prefix;
        };
      };
    };
  };
}
