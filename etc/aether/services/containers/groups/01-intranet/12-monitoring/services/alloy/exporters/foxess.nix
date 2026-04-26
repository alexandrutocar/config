{

  lib,
  pkgs,
  ...
}: {

  
  # FOXESS-PROMETHEUS EXPORTER SERVICE
  # ----------------------------------
  systemd.services.prometheus-foxess-exporter = let
    inherit (lib.extra.systemd) mkSetCredentialEncrypted;
    inherit (lib.meta) getExe;
  in {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      SetCredentialEncrypted = mkSetCredentialEncrypted {
        cloud-api-key = ''
          Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAmfLp5bbL/GOmaZEMAAAAAqeAvL
          WN/JnC2LLEPFLMN7xzbFt+W4SV3IodWPtWgvriM52A2V+uw3pDfxmZ4GlIzJrqVtC393R
          P22ArHQmOKGgOPly8fXrssv0r6ALk746lAm0qoRXDPczTkprg=
        '';
      };
      ExecStart = getExe (
        pkgs.custom.writeShell "prometheus-foxess-exporter.bash" {
          inputs = with pkgs.custom; [foxessprom];
          text = ''
            foxessprom --bind 127.0.0.1:9092 --cloud-api-key "$CLOUD_API_KEY" --cloud-update-freq 300
          '';
          env = {
            CLOUD_API_KEY.cred = "cloud-api-key";
          };
        }
      );
      DynamicUser = true;
      Restart = "always";
    };
  };
}
