{lib, ...}: let
  inherit (lib.modules) mkForce;
in {
  boot.initrd.network.enable = false;

  # Disable any and all network services.
  # The goal is to thwart network capability.
  networking = {
    resolvconf.enable = false;
    dhcpcd.enable = false;
    dhcpcd.allowInterfaces = [];
    interfaces = {};
    firewall.enable = true;
    useDHCP = false;
    useNetworkd = false;
    wireless.enable = false;
    networkmanager.enable = mkForce false;
  };
}
