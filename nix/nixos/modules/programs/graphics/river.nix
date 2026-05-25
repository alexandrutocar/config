# Copyright (c) 2003-2025 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ────────────────────────────────────────────────────────────────────────
# NOTE: This module keeps the general structure of the upstream one but
#       applies a few adjustments tailored to my setup. Only the pieces
#       I actually use are kept; unused options have been trimmed. Some
#       defaults have been changed/removed to reduce noise and clutter.
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.programs.river;
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "programs/wayland/river.nix"
  ];

  options.programs.river = let
    inherit (lib.options) mkEnableOption mkPackageOption;
  in {
    enable = mkEnableOption "river";

    package = mkPackageOption pkgs "river" {};
  };

  config = let
    inherit (lib.modules) mkIf;
  in
    mkIf cfg.enable {
      environment.systemPackages = [
        cfg.package
      ];

      xdg.portal = {
        enable = true;

        extraPortals = with pkgs; [
          xdg-desktop-portal-wlr
        ];

        config.common.default = "*";
      };
    };
}
