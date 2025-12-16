# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ ▀█▀ █▀▀ █▀
# ██▄ ░█░ █▄▄ ▄█
#
# ────────────────────────────────────────────────────────────────────────
{modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../../shared/settings/initrd.nix
    ../../shared/settings/net.nix
  ];

  # ignore lid state. it should remain running.
  hardware.sensor.lid.enable = false;

  # Configuration files and access credentials for `nixos-install`
  isoImage.contents = [
    # {
    #   source = ../shared/defaults/minimal;
    #   target = "/configuration"; # /iso/configuration
    # }
  ];
}
