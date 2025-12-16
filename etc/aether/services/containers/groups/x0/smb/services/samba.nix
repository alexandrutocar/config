# ────────────────────────────────────────────────────────────────────────
#
# █▀ ▄▀█ █▀▄▀█ █▄▄ ▄▀█
# ▄█ █▀█ █░▀░█ █▄█ █▀█
#
# samba, file sharing, smb...
#
# ────────────────────────────────────────────────────────────────────────
{container, ...}: let
  inherit (container) self;
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
      global = {
        "disable netbios" = "yes";
        "server string" = "Samba %v on %h";
        "workgroup" = "AETHER";

        # Network
        "hosts allow" = "192.168.0. 10.200.200. 192.168.1. aether.ip"; # lan, vpn, wg0,
        "hosts deny" = "ALL";
        "interfaces" = "${self.address}";
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

        "smb encrypt" = "required";

        "use sendfile" = "yes";

        "min receivefile size" = "16384";
        "getwd cache" = "true";
        "socket options" = "TCP_NODELAY IPTOS_THROUGHPUT SO_RCVBUF=65536 SO_SNDBUF=65536";
      };
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
