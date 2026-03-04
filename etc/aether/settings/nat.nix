# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ ▄▀█ ▀█▀
# █░▀█ █▀█ ░█░
#
# nat, network address translation, networking...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  networking.firewall.trustedInterfaces = ["wg0"];

  networking.nat = {
    enable = true;
    enableIPv6 = true;

    externalInterface = "wlan0";
    internalInterfaces = [
      "ve-*"
      "wg0"
    ];
  };
}
