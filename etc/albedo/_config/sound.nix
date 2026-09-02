# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▀█ █░█ █▄░█ █▀▄
# ▄█ █▄█ █▄█ █░▀█ █▄▀
#
# sound server, session manager, policies, mixer...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # BLUETOOTH DEVICE EXPLORER
    bluez-tools
    bluez

    # BLUETOOTH SELECTOR
    bluetui

    # AUDIO MIXER
    wiremix
  ];

  # BLUETOOTH
  # ---------
  hardware.bluetooth = {
    settings = {
      General = {
        Experimental = true;

        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Try disabling the option if any issues arise (spec. connecting to
        #       older devices which do may not implement the privacy features).
        # ────────────────────────────────────────────────────────────────────────
        Privacy = "on";
      };
    };
  };

  # LOCAL SERVICE DISCOVERY
  # -----------------------
  services.avahi = {
    enable = true;
  };

  # MULTIMEDIA SERVER
  # -----------------
  services.pipewire = {
    enable = true;

    # POLICY MANAGER
    # --------------
    wireplumber = {
      enable = true;
    };
  };

  # REAL-TIME SCHEDULING
  # --------------------
  security.rtkit.enable = true;

  environment.persistence = {
    "/state" = {
      directories = [
        # bluetooth devices
        "/var/lib/bluetooth"
      ];
    };
  };
}
