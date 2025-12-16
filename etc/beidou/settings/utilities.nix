# ────────────────────────────────────────────────────────────────────────
#
# █░█ ▀█▀ █ █░░ █ ▀█▀ █ █▀▀ █▀
# █▄█ ░█░ █ █▄▄ █ ░█░ █ ██▄ ▄█
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Tools for backing up keys
    paperkey
    pgpdump
    parted

    age

    # Yubico's official tools
    yubikey-manager
    yubico-piv-tool

    # Testing
    ent

    # Password generation tools
    diceware
    pwgen
    rng-tools

    # Might be useful beyond the scope of the guide
    cfssl
    pcsc-tools
  ];

  services.udev = {
    packages = with pkgs; [
      yubikey-manager
    ];
  };
}
