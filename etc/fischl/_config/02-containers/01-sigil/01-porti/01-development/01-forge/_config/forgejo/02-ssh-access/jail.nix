{
  config,
  lib,
  ...
}: let
  inherit (lib.strings) concatMapStringsSep;
in {
  services = {
    # Fail2Ban
    # --------
    fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        maxtime = "1w";
        overalljails = true;
      };

      jails = {
        sshd = {
          settings = {
            port = concatMapStringsSep "," toString config.services.openssh.ports;
            enabled = true;
            findtime = "1h";
            # ────────────────────────────────────────────────────────────────────────
            # NOTE: Bans scanners that never authenticate and clients whose OpenSSH is
            #       too old for the post-quantum key exchange.
            # ────────────────────────────────────────────────────────────────────────
            mode = "aggressive";
          };
        };
      };
    };

    openssh = {
      settings = {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Fail2Ban reads journal.
        # ────────────────────────────────────────────────────────────────────────
        LogLevel = "VERBOSE";

        # Built-in Resource Limits
        # ------------------------
        LoginGraceTime = 30;
        MaxAuthTries = 3;
        MaxStartups = "10:30:60";
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;

        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Clients are counted per /64 blocks.
        # ────────────────────────────────────────────────────────────────────────
        PerSourceNetBlockSize = "32:64";
      };
    };
  };
}
