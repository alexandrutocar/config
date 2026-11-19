{config, ...}: let
  inherit (config.services) forgejo;
in {
  users = {
    groups = {
      ${forgejo.group} = {};
    };

    users = {
      ${forgejo.user} = {
        home = "/var/lib/${forgejo.user}";

        inherit (forgejo) group;

        createHome = true;

        # ────────────────────────────────────────────────────────────────────────
        # NOTE: sshd runs 'forgejo serv' through the user's shell.
        # ────────────────────────────────────────────────────────────────────────
        useDefaultShell = true;

        isSystemUser = true;
      };
    };
  };

  services = {
    forgejo = let
      user = "git";
      group = user;
    in {
      inherit group user;
    };
  };
}
