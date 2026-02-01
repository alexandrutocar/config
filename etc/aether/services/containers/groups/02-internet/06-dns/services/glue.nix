# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █░░ █░█ █▀▀
# █▄█ █▄▄ █▄█ ██▄
#
# glue, records, updater...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  ...
}: let
  inherit (lib.custom.systemd) mkSetCredentialEncrypted;
in {
  custom.services.glue = {
    enable = true;
    settings = {
      "ueuie.dev" = {
        glue-prefix = "ns.aether.";
      };
    };
  };

  systemd.services = {
    ${config.custom.services.glue.settings."ueuie.dev".serviceUnitName} = {
      serviceConfig = {
        SetCredentialEncrypted = mkSetCredentialEncrypted {
          # systemd-ask-password -n | systemd-creds encrypt --name=porkbun-api-token -p - -
          porkbun-api-token = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAnInv9JO8byuv7GyUAAAAAhzvgw
            a0Z2bFjovGCwunwmoa2lm92jvdO1zBGngnAejMVnxCzyWvxkkaPW+sQK6V9OKO8Ec8qVh
            oUI3C9+jOJACMWOI/MbP5QY1LPKAAPRwvBjeBEsGazVqXFhlbwNPNtN3wXGGeiTrvh3AI
            422eYpYepVTPtQwF8NesTMA==
          '';
          # systemd-ask-password -n | systemd-creds encrypt --name=porkbun-api-secret -p - -
          porkbun-api-secret = ''
            Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAB8HmbriC0lh5AY0bkAAAAAY4AOE
            bu14jfHkBISSk3Kux1zXxh6X0AvEpm8RCjvV9yHUw0OA+ercnfJr24YV9/9s/aNiEqqSJ
            93i723hfx8Hst6vl7EW2NEAR2hHB11rqsDCEmPCFjPZ7ZcsjHJQXihTx2rCvrdpV4SH7Z
            8MfYV1uAwvrbAs0biSr0ItQ==
          '';
        };
      };
    };
  };

  systemd.timers = {
    ${config.custom.services.glue.settings."ueuie.dev".serviceUnitName} = {
      timerConfig = {
        OnCalendar = "*:0/5";
      };
    };
  };
}
