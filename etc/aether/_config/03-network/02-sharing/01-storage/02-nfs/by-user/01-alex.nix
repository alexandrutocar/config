{lib, ...}: let
  inherit (lib.modules) mkAfter;
in let
  user = "alex";
in {
  services = {
    nfs.server = {
      exports = mkAfter ''
        /export/share/${user} fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a(rw,nohide,insecure,no_subtree_check)
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
