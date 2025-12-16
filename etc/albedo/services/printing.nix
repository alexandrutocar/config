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

  hardware.printers = {
    ensureDefaultPrinter = "Drucker";
    ensurePrinters = [
      {
        name = "Drucker";
        model = "everywhere";
        deviceUri = "ipp://192.168.0.5/ipp";
      }
    ];
  };
}
