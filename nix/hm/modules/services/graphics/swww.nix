# MIT License
#
# Copyright (c) 2017-2025 Home Manager contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.swww;
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/swww.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkPackageOption;
  in {
    services.swww = {
      enable = mkEnableOption "swww";
      package = mkPackageOption pkgs "swww" {};
    };
  };

  config = let
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf;
  in
    mkIf cfg.enable {
      systemd.user.services = {
        swww = {
          Unit = {
            After = ["graphical-session.target"];
            PartOf = ["graphical-session.target"];
            Requires = ["graphical-session.target"];

            ConditionEnvironment = "WAYLAND_DISPLAY";
          };

          Service = {
            ExecStart = "${getExe cfg.package}/bin/swww-daemon";
            Type = "simple";
            #            # IMPORTANT: Must be set to user's home directory!
            #            WorkingDirectory = "/home/alex";

            Restart = "on-failure";
            Slice = ["session-graphical.slice"];
          };

          Install = {
            WantedBy = [
              "graphical-session.target"
            ];
          };
        };
      };
    };
}
