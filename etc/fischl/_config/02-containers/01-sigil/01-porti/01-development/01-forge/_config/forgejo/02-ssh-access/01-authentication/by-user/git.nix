{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.meta) getExe;
in let
  inherit (config.services) forgejo;
in {
  users = {
    users = {
      ${forgejo.user} = {
        extraGroups = [
          config.users.groups.ssh.name
        ];
      };
    };
  };

  environment = {
    etc = {
      "ssh/forgejo-keys" = {
        # ────────────────────────────────────────────────────────────────────────
        # NOTE: Makes this a root-owned regular file, satisfying sshd's permission
        #       checks on 'AuthorizedKeysCommand'.
        # ────────────────────────────────────────────────────────────────────────
        mode = "0755";

        # ────────────────────────────────────────────────────────────────────────
        # NOTE: --work-path pins what would otherwise be derived from binary's
        #       store location.
        # ────────────────────────────────────────────────────────────────────────
        text = ''
          #!${pkgs.runtimeShell}
          exec ${getExe forgejo.package} --work-path ${forgejo.stateDir} --config ${forgejo.customDir}/conf/app.ini keys "$@"
        '';
      };
    };
  };

  services = {
    openssh = {
      extraConfig = let
        keysCommand = "/etc/${config.environment.etc."ssh/forgejo-keys".target}";
      in ''
        Match User ${forgejo.user}
          AuthorizedKeysFile none
          AuthorizedKeysCommand ${keysCommand} -e ${forgejo.user} -u %u -t %t -k %k
          AuthorizedKeysCommandUser ${forgejo.user}
          AuthenticationMethods publickey
          DisableForwarding yes
          PermitTTY no
          PermitUserRC no
          PermitTunnel no
      '';
    };
  };
}
