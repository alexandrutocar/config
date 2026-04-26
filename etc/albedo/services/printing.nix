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

  environment.systemPackages = with pkgs; [
    naps2
  ];

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
