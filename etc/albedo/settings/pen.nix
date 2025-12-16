#
# █▀█ █▀▀ █▄░█
# █▀▀ ██▄ █░▀█
#
# penetration testing, network analysis, security
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  # WIRESHARK
  programs.wireshark = {
    enable = true;
    package = with pkgs; wireshark;
    usbmon.enable = true;
    dumpcap.enable = true;
  };
}
