{lib, ...}: let
  inherit (lib.alias) radii;
  inherit (lib.extra) ip;
  inherit (lib.modules) mkAfter;
in let
  user = "alex";
in {
  services = {
    nfs.server = {
      exports = mkAfter ''
        /export/share/${user} ${(radii.site.albedo.hostAddress |> ip.toCompressed)}(rw,nohide,insecure,no_subtree_check)
      '';
    };
  };

  fileSystems = {
    "/export/share/${user}" = {
      device = "/archive";
      fsType = "none";
      options = ["bind"];
    };
  };
}
