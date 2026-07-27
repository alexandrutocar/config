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
_: {
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
        /export             fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a(rw,fsid=0,no_subtree_check)
      '';
    };
  };
}
