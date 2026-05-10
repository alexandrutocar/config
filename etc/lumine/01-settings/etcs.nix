# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ ▀█▀ █▀▀ █▀
# ██▄ ░█░ █▄▄ ▄█
#
# ────────────────────────────────────────────────────────────────────────
{
  modulesPath,
  self,
  lib,
  ...
}: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    (self + /etc/shared/01-settings/net.nix)
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
