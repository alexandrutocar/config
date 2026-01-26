# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ ▀█▀ █▀▀ █▀
# ██▄ ░█░ █▄▄ ▄█
#
# etcs, everything else...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  system = {
    etc.overlay.enable = mkDefault true;

    nixos-init.enable = true;

    # Disabled Tools
    tools = {
      nixos-build-vms.enable = lib.mkDefault false;
      nixos-generate-config.enable = lib.mkDefault false;
    };
  };

  # Disabled Docs
  documentation = {
    enable = mkDefault false;

    doc.enable = mkDefault false;
    info.enable = mkDefault false;
    nixos.enable = mkDefault false;
  };
}
