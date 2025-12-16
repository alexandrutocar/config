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
    enable = true;

    settings = {
      General = {
        ControllerMode = "dual";
        FastConnectable = "true";
        Experimental = "true";
      };
      Policy = {
        AutoEnable = "true";
      };
    };
  };

  # LOCAL SERVICE DISCOVERY
  # -----------------------
  services. avahi = {
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
  #
  # TODO
  # - Give sound server real-time scheduling priority.
  #   - Is RTKit maintained?
  #
  # --------------------
  # security.rtkit.enable = true;

  environment.persistence."/state".directories = [
    # bluetooth devices
    "/var/lib/bluetooth"
  ];
}
