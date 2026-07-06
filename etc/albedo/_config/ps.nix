# ────────────────────────────────────────────────────────────────────────
#
# █▀█ █▀█ █ █▄░█ ▀█▀ █ █▄░█ █▀▀
# █▀▀ █▀▄ █ █░▀█ ░█░ █ █░▀█ █▄█
#
# printers, scan, print...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  # LOCAL SERVICE DISCOVERY
  # -----------------------
  services.avahi = {
    enable = true;
  };

  # SCAN SERVICES
  # -------------
  hardware.sane = {
    enable = true;
  };

  # PRINT SERVICES
  # --------------
  services.printing = {
    enable = true;

    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };
}
