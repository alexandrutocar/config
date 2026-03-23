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
  cfg = config.services.ssh-agent;
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/ssh-agent.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkPackageOption;
  in {
    services.ssh-agent = {
      enable = mkEnableOption "OpenSSH private key agent";
      
      package = mkPackageOption pkgs "openssh" { };
    };
  };

  config = let
    inherit (lib.meta) getExe';
    inherit (lib.modules) mkIf mkMerge;
  in
    mkIf cfg.enable (mkMerge [
      {
        assertions = [
          (lib.hm.assertions.assertPlatform "services.ssh-agent" pkgs lib.platforms.linux)
        ];
      }
      {
        home.sessionVariablesExtra = let 
          socketPath = "$XDG_RUNTIME_DIR/ssh-agent.socket";
        in ''
          if [ -z "$SSH_AUTH_SOCK" -o -z "$SSH_CONNECTION" ]; then
            export SSH_AUTH_SOCK=${socketPath}
          fi
        '';
      }
      {
        systemd.user = {
          services.ssh-agent = {
            Unit = {
              ConditionEnvironment = ["!SSH_AGENT_PID"];
              Description = "SSH Key Agent";
              Documentation = "man:ssh-agent(1) man:ssh-add(1) man:ssh(1)";
              Requires = ["ssh-agent.socket"];
            };

            Service = {
              ExecStart = "${getExe' cfg.package "ssh-agent"} -D";
              SuccessExitStatus = [2];
            };

            Install = {
              Also = ["ssh-agent.socket"];
            };
          };
        };
      }
      {
        systemd.user.sockets.ssh-agent = {
          Unit = {
            ConditionEnvironment = ["!SSH_AGENT_PID"];
            Description = "Socket for the SSH Key Agent";
            Documentation = "man:ssh-agent(1)";
          };

          Socket = {
            ListenStream = "%t/ssh-agent.socket";
            RemoveOnStop = true;
          };

          Install = {
            WantedBy = ["sockets.target"];
          };
        };
      }
    ]
  );
}
