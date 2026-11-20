lib: let
  inherit (lib.alias) addresses;
  inherit (lib.extra) ip;
in {
  albedo = let
    _prefix = ip.network.fromCIDR 6 "fdb0:c57e:ce7b::/48";
    _hostSubnet = ip.network.subnetAt _prefix 64 (lib.fromHexString "9aa2");
  in {
    availableNetworks = ["0.0.0.0/0" "::/0"];

    publicKey = "mF4+HKwkgxXVfyRBUnTqDWCpH58PmYXbYGjHS+r4u10=";

    id = 1;

    hostAddress = ip.network.hostAddress _hostSubnet "::fb58:495a:7384:3204" |> ip.address.singleHostRoute;
  };

  beidou = let
    prefix = ip.network.fromCIDR 6 "fda0:9527:68ee::/48";
    _hostSubnet = ip.network.subnetAt prefix 64 (lib.fromHexString "4f8a");
  in
    {
      inherit prefix;

      availableNetworks = ["0.0.0.0/0" "::/0"];

      publicKey = "8mCsOnxmQW+P8jomk9nb37i2TD/8cuxO44yP8pETrgc=";

      id = 2;

      hostAddress = ip.network.hostAddress _hostSubnet "::f7f3:176c:41e0:4098" |> ip.address.singleHostRoute;
    }
    // (let
      systemSite = addresses.on-prem.specht;
    in {
      openPorts = [50001 [50003 50005]];

      basePort = 50000;

      endpoints = (with systemSite; [hosts.beidou.ipv6.gua router.ipv4.wan]) |> map ip.address.singleHostRoute;
    });

  collei = let
    prefix = ip.network.fromCIDR 6 "fdfc:6eab:7c7e::/48";
    _hostSubnet = ip.network.subnetAt prefix 64 (lib.fromHexString "feea");
  in
    {
      inherit prefix;

      availableNetworks = ["::/0"];

      publicKey = "zm+oSPyszYI6Bf3QBEzvf9QPmtLL9ktfLy/lEsLoBVA=";

      id = 3;

      hostAddress = ip.network.hostAddress _hostSubnet "::d067:55e5:ca17:783c" |> ip.address.singleHostRoute;
    }
    // (let
      systemSite = addresses.provider.hetzner-cloud-server;
    in {
      openPorts = [[51821 51822] [51824 51825]];

      basePort = 51820;

      endpoints =
        (with systemSite.hosts.collei; [
          ipv4.wan
          ipv6.gua
        ])
        |> map ip.address.singleHostRoute;
    });

  fischl = let
    prefix = ip.network.fromCIDR 6 "fd56:356d:3abc::/48";
    _hostSubnet = ip.network.subnetAt prefix 64 (lib.fromHexString "b31b");
  in {
    inherit prefix;

    availableNetworks = ["0.0.0.0/0"];

    publicKey = "l+FDdOIrdyBGP0yr4/ngHD9P5f4HjkbMLL5cb600fDo=";

    id = 4;

    hostAddress = ip.network.hostAddress _hostSubnet "::6e11:2c8:2bd:6c86" |> ip.address.singleHostRoute;
  };

  keqing = let
    prefix = ip.network.fromCIDR 6 "fd9f:4084:104d::/48";
    _hostSubnet = ip.network.subnetAt prefix 64 (lib.fromHexString "484a");
  in {
    availableNetworks = ["0.0.0.0/0" "::/0"];

    publicKey = "yUL/7L+Mtu5r4CIS31icTXzTZ3sZzYO41cTNLUV5dF0=";

    kind = "device";

    id = 5;

    hostAddress = ip.network.hostAddress _hostSubnet "::b31b:23d2:c2a6:a48a" |> ip.address.singleHostRoute;
  };
}
