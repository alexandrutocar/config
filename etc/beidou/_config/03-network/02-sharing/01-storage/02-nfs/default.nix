# spell-checker: ignore fsid nohide
# ────────────────────────────────────────────────────────────────────────
# NOTE: NFS is the most reliable network file sharing protocol for Linux.
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.alias) radii;
  inherit (lib.extra) ip;
in {
  networking = {
    firewall = {
      extraInputRules = ''
        ip6 saddr ${radii.site.albedo.hostAddress |> ip.toCompressed} tcp dport 2049 accept
      '';
    };
  };

  services = {
    nfs.server = {
      enable = true;

      exports = ''
        /export             ${(radii.site.albedo.hostAddress |> ip.toCompressed)}(rw,fsid=0,no_subtree_check)
      '';
    };
  };
}
