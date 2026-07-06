_: let
  share = "/share/alex";
  where = "/mnt/${share}";
in {
  systemd = {
    automounts = [
      {
        inherit where;
        wantedBy = ["multi-user.target"];
        automountConfig = {
          TimeoutIdleSec = "600";
        };
      }
    ];

    mounts = [
      {
        inherit where;
        type = "nfs";
        mountConfig = {
          Options = "noatime";
        };
        what = "aether.hosts.net.internal:${share}";
      }
    ];
  };
}
