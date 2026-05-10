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

    externalInterface = "enp0s20f0u2";
    internalInterfaces = [
      "ve-*"
      "wg0"
    ];
  };
}
