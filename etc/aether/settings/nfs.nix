_: {
  fileSystems = {
    "/export/archive" = {
      device = "/archive";
      options = ["bind"];
    };
  };

  services.nfs.server.enable = true;

  services.nfs.server.exports = ''
    /export           192.168.1.2(rw,fsid=0,no_subtree_check)
    /export/archive   192.168.1.2(rw,nohide,insecure,no_subtree_check)
  '';

  networking.firewall.allowedTCPPorts = [2049];
}
