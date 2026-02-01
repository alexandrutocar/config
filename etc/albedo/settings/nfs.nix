_: {
  boot.supportedFilesystems = ["nfs"];

  services.rpcbind.enable = true;

  systemd.mounts = [
    {
      type = "nfs";
      mountConfig = {
        Options = "noatime";
      };
      what = "aether.ip:/alex";
      where = "/mnt/alex";
    }
  ];

  systemd.automounts = [
    {
      wantedBy = ["multi-user.target"];
      automountConfig = {
        TimeoutIdleSec = "600";
      };
      where = "/mnt/alex";
    }
  ];
}
