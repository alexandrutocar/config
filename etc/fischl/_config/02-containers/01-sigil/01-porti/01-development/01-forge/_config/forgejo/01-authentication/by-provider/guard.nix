{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkAfter;
in let
  inherit (config.services) forgejo;

  provider = {
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: https://forge.ueuie.earth/user/oauth2/Guard/callback would be the
    #       callback path registered at Guard.
    # ────────────────────────────────────────────────────────────────────────
    name = "Guard";

    client = {
      id = "aa76e9fb-87d7-45f3-acff-3b725aa1400d";

      secret = {
        name = "oauth2-guard-client-secret";
      };
    };

    issuer = "https://guard.ueuie.earth";

    groups = {
      users = "forgejo";
      admin = "forgejo_admin";
    };
  };
in {
  systemd = {
    services = {
      forgejo = {
        serviceConfig = {
          SetCredentialEncrypted = mkSetCredentialEncrypted {
            # echo -n '<secret>' | systemd-creds encrypt --with-key=host --name=oauth2-guard-client-secret - -
            ${provider.client.secret.name} = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAACldeGumk9AxcgYy7cAAAAA+vnEN0DYLFj6z/9
              EyzBAoM8ztVFyvjTs+HWOt8EiaC+sH9zZ4ExHrRbPDnKBCXuSzxxCU9kN9MixxLRBs6zae+KqoGMitZ
              7SWULuRKBa/x1ePXLf4M7JtPGsFydu1Z9J
            '';
          };
        };

        # Create/update the Guard login source before the web server starts
        # (runs after the module's own migrations, as the service user).
        preStart = mkAfter ''
          _forgejo() {
            ${getExe forgejo.package} --work-path ${forgejo.stateDir} --config ${forgejo.customDir}/conf/app.ini "$@"
          }

          args=(
            --name ${provider.name}
            --provider openidConnect
            --key ${provider.client.id}
            --secret "$(< "${credentialsDirectory "forgejo"}/${provider.client.secret.name}")"
            --auto-discover-url ${provider.issuer}/.well-known/openid-configuration
            --scopes openid --scopes email --scopes profile --scopes groups
            --group-claim-name groups
            --required-claim-name groups
            --required-claim-value ${provider.groups.users}
            --admin-group ${provider.groups.admin}
            --skip-local-2fa
          )

          id=$(_forgejo admin auth list --vertical-bars \
            | ${getExe pkgs.gawk} -F'|' '{ gsub(/[ \t]/, "", $1); gsub(/[ \t]/, "", $2) } $2 == "${provider.name}" { print $1 }')

          if [ -n "$id" ]; then
            _forgejo admin auth update-oauth --id "$id" "''${args[@]}"
          else
            _forgejo admin auth add-oauth "''${args[@]}"
          fi
        '';
      };
    };
  };
}
