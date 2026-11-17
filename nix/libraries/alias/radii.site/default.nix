lib: let
  inherit (lib.alias) addresses networks;
  inherit (lib.extra) ip;
in {
  albedo = {
    id = 1;
    hostAddress = "fdb0:c57e:ce7b:9aa2:fb58:495a:7384:3204";
    publicKey = "mF4+HKwkgxXVfyRBUnTqDWCpH58PmYXbYGjHS+r4u10=";
    availableNetworks = ["0.0.0.0/0" "::/0"];
  };

  beidou = {
    id = 2;
    hostAddress = networks.aether.internal.net.hosts.beidou |> ip.address.singleHostRoute;
    prefix = "fda0:9527:68ee::/48";
    publicKey = "8mCsOnxmQW+P8jomk9nb37i2TD/8cuxO44yP8pETrgc=";
    availableNetworks = ["0.0.0.0/0" "::/0"];
    endpoints =
      [
        addresses.on-prem.specht.hosts.beidou.ipv6.gua
        addresses.on-prem.specht.router.ipv4.wan
      ]
      |> map ip.address.singleHostRoute;
    basePort = 50010;
  };

  collei = {
    id = 3;
    hostAddress = "fdfc:6eab:7c7e:feea:d067:55e5:ca17:783c";
    prefix = "fdfc:6eab:7c7e::/48";
    publicKey = "zm+oSPyszYI6Bf3QBEzvf9QPmtLL9ktfLy/lEsLoBVA=";
    availableNetworks = ["::/0"];
    endpoints =
      [
        addresses.provider.hetzner-cloud-server.hosts.collei.ipv6.gua
      ]
      |> map ip.address.singleHostRoute;
    basePort = 51820;
  };

  fischl = {
    id = 4;
    hostAddress = "fd56:356d:3abc:b31b:6e11:02c8:02bd:6c86";
    prefix = "fd56:356d:3abc::/48";
    publicKey = "l+FDdOIrdyBGP0yr4/ngHD9P5f4HjkbMLL5cb600fDo=";
    availableNetworks = ["0.0.0.0/0"];
  };

  keqing = {
    id = 5;
    kind = "device";
    hostAddress = "fd9f:4084:104d:484a:b31b:23d2:c2a6:a48a";
    publicKey = "yUL/7L+Mtu5r4CIS31icTXzTZ3sZzYO41cTNLUV5dF0=";
    availableNetworks = ["0.0.0.0/0" "::/0"];
  };
}
