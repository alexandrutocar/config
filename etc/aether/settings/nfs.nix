_: {
  fileSystems."/export/alex" = {
    device = "/blobs/var/lib/machines/01-intranet/09-storage/var/lib/samba/private/share";
    options = ["bind"];
  };

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export       192.168.0.187(rw,fsid=0,no_subtree_check)
    /export/alex  192.168.0.187(rw,nohide,insecure,no_subtree_check)
  '';

  networking.firewall.allowedTCPPorts = [2049];
}
