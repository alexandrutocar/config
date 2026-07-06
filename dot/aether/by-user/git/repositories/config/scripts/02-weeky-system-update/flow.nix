{
  lib,
  pkgs,
  ...
}: let
  meta = {
    repo = {
      name = "systems";
      path = "/var/lib/git/systems";
    };
    flow = {
      name = "weekly-system-update";
    };
  };
in {
  # systemd.user.services.${meta.flow.name} = let
  #   inherit (lib.meta) getExe;
  # in {
  #   # [Unit]
  #   Unit = {
  #     Description = "'${meta.flow.name}' flow run for the '${meta.repo.name}' repository.";
  #   };

  #   # [Service]
  #   Service = {
  #     Type = "oneshot";
  #     ExecStart = let
  #       repo = {
  #         name = "repository";
  #         path = "/tmp/repository";
  #       };
  #     in
  #       getExe (
  #         pkgs.custom.writeShell "${meta.flow.name}.bash" {
  #           inputs = with pkgs; [
  #             coreutils
  #             git
  #           ];
  #           text = builtins.readFile ./flow.bash;
  #           env = {
  #             FLOW_REPO_PATH = repo.path;
  #             GIT_CEILING_DIRECTORIES = "/var/lib/git";
  #           };
  #         }
  #       );

  #     # HARDENING
  #     # ---------
  #     PrivateTmp = true;
  #   };
  # };

  # systemd.user.timers.${meta.flow.name} = {
  #   # [Unit]
  #   Unit = {
  #     Description = "";
  #     Documentation = [];
  #   };

  #   # [Timer]
  #   Timer = {
  #     OnCalendar = "Sat *-*-* 00:00:00 Europe/Berlin";
  #     Persistent = true;
  #   };

  #   # [Install]
  #   Install = {
  #     WantedBy = "timers.target";
  #   };
  # };
}
