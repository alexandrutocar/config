_: {
  services.rpcbind = {
    enable = true;
  };

  boot = {
    supportedFilesystems = ["nfs"];
  };
}
