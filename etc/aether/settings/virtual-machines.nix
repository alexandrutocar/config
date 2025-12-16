# ────────────────────────────────────────────────────────────────────────
#
# █░█ █ █▀█ ▀█▀ █░█ ▄▀█ █░░   █▀▄▀█ ▄▀█ █▀▀ █░█ █ █▄░█ █▀▀ █▀
# ▀▄▀ █ █▀▄ ░█░ █▄█ █▀█ █▄▄   █░▀░█ █▀█ █▄▄ █▀█ █ █░▀█ ██▄ ▄█
#
# containers, docker, qemu, kvm, virsh...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  # ────────────────────────────────────────────────────────────────────────
  # TODO: Is it needed?
  # ────────────────────────────────────────────────────────────────────────
  # boot = {
  #   # enable kernel level virtualization
  #   kernelModules = [
  #     "kvm-amd"
  #   ];

  #   # enable input output memory management unit
  #   kernelParams = [
  #     "amd_iommu=on"
  #     "iommu=on"
  #   ];
  # };

  # environment.systemPackages = with pkgs; [
  #   virtiofsd
  #   spice

  #   # Management
  #   qemu
  # ];

  # # VIRTUALISATION PLATFORM MANAGEMENT
  # # ----------------------------------
  # virtualisation.libvirtd = {
  #   enable = true;

  #   # FULL-SYSTEM EMULATION
  #   # ---------------------
  #   qemu = {
  #     swtpm.enable = true;
  #   };
  # };

  # networking.firewall.trustedInterfaces = ["virbr0"];

  # environment.persistence."/state".directories = [
  #   "/var/cache/libvirt"
  #   "/var/lib/libvirt"
  # ];
}
