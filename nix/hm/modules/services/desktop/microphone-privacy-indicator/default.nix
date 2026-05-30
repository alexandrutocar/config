{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.microphone-privacy-indicator;
in let
  meta = {
    description = "A service that keeps microphone privacy indicator in sync with PipeWire's mute state.";
  };
in {
  meta.maintainers = with lib.maintainers; [alexandrutocar];

  options = let
    inherit (lib.options) mkEnableOption;
  in {
    services.microphone-privacy-indicator = {
      enable = mkEnableOption meta.description;
    };
  };

  config = let
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf;
  in
    mkIf cfg.enable {
      systemd.user.services = {
        microphone-privacy-indicator = {
          Unit = {
            Description = meta.description;
            After = ["wireplumber.service"];
            Wants = ["wireplumber.service"];
          };
          Service = {
            ExecStart = getExe (
              pkgs.custom.writeShell "microphone-privacy-indicator" {
                inputs = with pkgs; [brightnessctl jq pipewire];
                text = builtins.readFile ./scripts/microphone-privacy-indicator.bash;
              }
            );
            Restart = "always";
          };
          Install = {
            WantedBy = ["wireplumber.service"];
          };
        };
      };
    };
}
