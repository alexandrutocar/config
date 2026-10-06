# ────────────────────────────────────────────────────────────────────────
#
# █▄▄ █▀█ █▀█ ▀█▀ █░░ █▀█ ▄▀█ █▀▄
# █▄█ █▄█ █▄█ ░█░ █▄▄ █▄█ █▀█ █▄▀
#
# TAGS: Boot, Bootloader, Lanzaboote
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  boot = {
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  environment.persistence = {
    "/state" = {
      directories = [
        config.boot.lanzaboote.pkiBundle
      ];
    };
  };
}
