# ────────────────────────────────────────────────────────────────────────
#
# █▀ ▄▀█ █▀▄▀█ █▄▄ ▄▀█
# ▄█ █▀█ █░▀░█ █▄█ █▀█
#
# samba, file sharing, smb...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  lib,
  ...
}: let
  inherit (container) self;

  inherit (lib.modules) mkMerge;
in {
  users.users.alex = {
    extraGroups = ["samba"];
    isNormalUser = true;
    # ────────────────────────────────────────────────────────────────────────
    # TODO: Is it really needed?
    # ────────────────────────────────────────────────────────────────────────
    hashedPasswordFile = "/etc/hashed/alex";
  };

  services.samba = {
    enable = true;

    nmbd.enable = false;
    nsswins = false;
    winbindd.enable = false;

    settings = {
      global = mkMerge [
        {
          "disable netbios" = "yes";
          "server string" = "Samba %v on %h";
          "workgroup" = "AETHER";

          # Network
          "hosts allow" = "172.16.1.3 aether.ip"; # vpn
          "hosts deny" = "ALL";
          "interfaces" = "${self.localAddress}";
          "bind interfaces only" = "yes";

          # Signing
          "client signing" = "required";
          "server signing" = "mandatory";

          # Protocol
          "client min protocol" = "smb3";
          "server min protocol" = "smb3";

          "client protection" = "sign";

          "restrict anonymous" = "2";

          "security" = "user";

          "smb encrypt" = "desired";

          "getwd cache" = "true";

          "use sendfile" = "yes";

          "min receivefile size" = "16384";
        }
        {
          "aio read size" = "16384";
          "aio write size" = "16384";
          "read raw" = "yes";
          "write raw" = "yes";
        }
        {
          "kernel oplocks" = "yes";
          "level2 oplocks" = "yes";
        }
        {
          "log level" = "1";
        }
      ];
      share = {
        "path" = "/var/lib/samba/private/share";
        "public" = "no";

        "browsable" = "yes";
        "available" = "yes";
        "read only" = "no";

        "guest ok" = "no";

        "valid users" = "alex";

        "create mask" = "0660"; #       create      permissions mask: 0660 ~ rw-rw----
        "directory mask" = "2750"; #    directory   permissions mask: 2750 ~ rwxr-x---
        "force directory mode" = "2770";

        "vfs objects" = "catia fruit streams_xattr"; # super important
      };
    };
  };
}
