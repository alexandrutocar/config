{lib, ...}: let
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCompressed;
  inherit (lib.modules) mkAfter;
in let
  user = "alex";
in {
  services = {
    nfs.server = {
      exports = mkAfter ''
        /export/share/${user} ${(networks.aether.internal.net.hosts.albedo |> toCompressed)}(rw,nohide,insecure,no_subtree_check)
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
