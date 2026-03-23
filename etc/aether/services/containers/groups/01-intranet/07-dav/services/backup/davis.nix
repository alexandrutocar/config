# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ ▄▀█ █░█ █ █▀   █▄▄ ▄▀█ █▀▀ █▄▀ █░█ █▀█
# █▄▀ █▀█ ▀▄▀ █ ▄█   █▄█ █▀█ █▄▄ █░█ █▄█ █▀▀
#
# davis database backup...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.systemd) mkSetCredentialEncrypted;
  inherit (lib.meta) getExe;

  inherit (container) intranet-database;
in {
  systemd.services."backup@davis" = {
    serviceConfig = {
      Type = "oneshot";

      ExecStart = getExe (
        pkgs.custom.writeShell "backup@davis.bash" {
          inputs = with pkgs; [postgresql restic];
          text = builtins.readFile ./davis.sh;
          env = {
            AWS_ACCESS_KEY_ID.cred = "access-key-id";
            AWS_SECRET_ACCESS_KEY.cred = "secret-access-key";
            RESTIC_REPOSITORY.cred = "restic-repository";
            RESTIC_PASSWORD.cred = "restic-password";

            PGHOST = intranet-database.localAddress;
            PGPORT = "5432";
            PGUSER = "davis";
          };
        }
      );

      SetCredentialEncrypted = mkSetCredentialEncrypted {
        # systemd-ask-password -n | systemd-creds encrypt --name=access-key-id -p - -
        access-key-id = ''
          Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAACVfmFd5p96s49x7UYAAAAAdpaoj
          lHhAyQVwGq6rHpQPo9OPuQgR8tLspl7zYvkww8kE3EZz+jKWPID3pDGoihA8NEe2Meytt
          vhsPBQrc7URzxMf2PROFyB/WLATFoghCSlN4ACj0DFpA==
        '';
        # systemd-ask-password -n | systemd-creds encrypt --name=secret-access-key -p - -
        secret-access-key = ''
          Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAcYRKuNom+8rFOIkYAAAAAW9CL0
          hTIAc/tohp+kC2EfD87r9xDnzFXEVaOFDQDjRxMuGcMZPhFkM+kG5AwmNQ6ET59y4pXCm
          uxJNv5IjZu/+vUjJlLCUPP31UxztAipwGkRl5Od8CQRbiDWdgDydqDQRaZ3oYev/1e1R8
          d48oJN2fAGbrtNxsD
        '';
        # systemd-ask-password -n | systemd-creds encrypt --name=restic-repository -p - -
        restic-repository = ''
          Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAA42P2V9eZcbQOoB50AAAAA9TdSQ
          Ed6HHb+k7fv8jTeFUpof69+Ykkct1fx7MNYZtWodmg9V7S7ySAwmMol9DoGsV9wrjJIwd
          Y2v5XRrBo9+EFeVIfvuGh5Z4cZgi3P/VR2tch821tTYj45HYWkg3cihzJmW/320jIfowk
          FQHK7VOHMI83+nLvaFk8+VOuoy9nB
        '';
        # systemd-ask-password -n | systemd-creds encrypt --name=restic-password -p - -
        restic-password = ''
          Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAa8Kv7CNDrtPrhrVoAAAAAzLKwo
          ou3r+KWDLC+k3Nh361U4+jzVmNeEQ4tC/XDOX9ThyVDO/y8XqrjFTbMvEKUpkN0VaBUDY
          bVNA0U9Cvq/EI9tfrNjBJ2+fPlm5UdNh/6NguvQglffg==
        '';
      };
    };
  };

  systemd.timers."backup@davis" = {
    timerConfig = {
      OnCalendar = "*-*-* 0/6:00:00";
    };
  };
}
