{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.creek;
in {
  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.strings) literalExpression;

    inherit (lib.extra.types.colors) hex;
    inherit (lib.types) nullOr int str submodule;
  in {
    services.creek = {
      enable = mkEnableOption "creek";
      package = mkPackageOption pkgs "creek" {};

      settings = mkOption {
        description = "creek for `creek(1)`.";
        default = {};
        example = literalExpression ''
          {
            font-name = "Tamsyn";
            font-size = 15;

            size = 17;

            foreground-color = "#aaaaaa";
            background-color = "#000000";
            focused-foreground-color = "#ffffff";
            focused-background-color = "#000000";
          }
        '';
        type = submodule (_: {
          options = {
            font-name = mkOption {
              type = nullOr str;
              default = "monospace";
              description = ''
                Font name.
              '';
            };
            font-size = mkOption {
              type = nullOr int;
              default = 10;
              description = ''
                Font size.
              '';
            };
            size = mkOption {
              type = nullOr int;
              default = 15;
              description = ''
                Font size.
              '';
            };
            foreground-color = mkOption {
              type = nullOr hex;
              default = "#b8b8b8";
              description = ''
                Text color.
              '';
            };
            background-color = mkOption {
              type = nullOr hex;
              default = "#282828";
              description = ''
                Background color.
              '';
            };
            focused-foreground-color = mkOption {
              type = nullOr hex;
              default = "#181818";
              description = ''
                Text color on focused tags.
              '';
            };
            focused-background-color = mkOption {
              type = nullOr hex;
              default = "#7cafc2";
              description = ''
                Background color on focused tags.
              '';
            };
          };
        });
      };
    };
  };

  config = let
    inherit (lib.extra.colors) hexToBin;
    inherit (lib.lists) optionals singleton;
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf;
    inherit (lib.strings) concatStringsSep;
  in
    mkIf cfg.enable {
      systemd.user.services.creek = {
        Unit = {
          Description = "Malleable and minimalist status bar for the River compositor";

          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
          Requires = ["graphical-session.target"];

          ConditionEnvironment = "WAYLAND_DISPLAY";
        };

        Service = {
          ExecStart = let
            args = optionals (cfg.settings != {}) [
              "-fn ${cfg.settings.font-name}:size=${toString cfg.settings.font-size}"
              "-hg ${toString cfg.settings.size}"
              "-nf ${hexToBin cfg.settings.foreground-color}"
              "-nb ${hexToBin cfg.settings.background-color}"
              "-ff ${hexToBin cfg.settings.focused-foreground-color}"
              "-fb ${hexToBin cfg.settings.focused-background-color}"
            ];
          in
            getExe (
              pkgs.custom.writeShell "creek.bash" {
                inputs = singleton cfg.package;
                text = ''
                  while date; do
                    sleep 1;
                  done | ${getExe cfg.package} ${
                    if args != []
                    then concatStringsSep " " args
                    else "# using default fonts, sizes and colors"
                  }
                '';
              }
            );

          Restart = "on-failure";
          Slice = ["session-graphical.slice"];
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
    };
}
