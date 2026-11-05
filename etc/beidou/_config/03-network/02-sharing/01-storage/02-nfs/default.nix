# spell-checker: ignore fsid nohide
# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █▀▀ █▀
# █░▀█ █▀░ ▄█
#
# TAGS: Network File System, NFS
# NOTE: NFS is the most reliable network file sharing protocol for Linux.
#
# ────────────────────────────────────────────────────────────────────────
{lib,...}: let 
  inherit (lib.alias) networks;
  inherit (lib.extra.ip) toCompressed;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        2049 # NFS
      ];
    };
  };

  services = {
    nfs.server = {
      enable = true;

      exports = ''
        /export             ${(networks.aether.internal.net.hosts.albedo |> toCompressed)}(rw,fsid=0,no_subtree_check)
      '';
    };
  };
}
