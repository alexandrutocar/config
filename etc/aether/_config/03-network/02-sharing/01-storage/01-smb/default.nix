# spell-checker: ignore catia getwd oplocks streams_xattr
# ────────────────────────────────────────────────────────────────────────
#
# █▀ █▀▄▀█ █▄▄
# ▄█ █░▀░█ █▄█
#
# TAGS: Samba, SMB/CIFS
# NOTE: SMB is the only supported protocol by iOS' built-in Files.
#
# ────────────────────────────────────────────────────────────────────────
_: {
  environment.persistence = {
    "/state" = {
      directories = [
        "/var/lib/samba/"
      ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      445 # SMB
    ];
  };

  services.samba = {
    enable = true;

    settings = {
      global = {
        "disable netbios" = "yes";
        "server string" = "Samba %v on %h";
        "workgroup" = "AETHER";

        # Network
        "hosts allow" = "172.16.1. intra.net.internal"; # vpn
        "hosts deny" = "ALL";
        "interfaces" = "lo wg0";
        "bind interfaces only" = "yes";

        # Signing
        "client signing" = "required";
        "server signing" = "mandatory";

        # Protocol
        "client min protocol" = "smb3";
        "server min protocol" = "smb3";

        "client protection" = "sign";

        "restrict anonymous" = "2";

        "smb encrypt" = "desired";

        "getwd cache" = "true";

        "use sendfile" = "yes";

        "min receivefile size" = "16384";

        "passwd program" = "/run/wrappers/bin/passwd %u";
        "invalid users" = [
          "root"
        ];
        "security" = "user";

        "aio read size" = "16384";
        "aio write size" = "16384";
        "read raw" = "yes";
        "write raw" = "yes";

        "kernel oplocks" = "yes";
        "level2 oplocks" = "yes";

        "log level" = "1";
      };
    };
  };
}
