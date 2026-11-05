{pkgs, ...}: {
  systemd.services = {
    "credential.secret" = {
      wantedBy = [
        "sysinit.target"
      ];

      after = [
        "systemd-tmpfiles-setup.service"
      ];

      before = [
        "sysinit.target"
      ];

      unitConfig = {
        DefaultDependencies = false;
        ConditionPathExists = "!/var/lib/systemd/credential.secret";
        RequiresMountsFor = ["/var/lib"];
      };
      serviceConfig = {
        Type = "oneshot";
        LoadCredential = [
          "credential.secret"
        ];
        UMask = "0377";
        ExecStart = pkgs.writeShellScript "credential.secret" ''
          install -m 0400 -o root -g root \
            "$CREDENTIALS_DIRECTORY/credential.secret" \
            /var/lib/systemd/credential.secret
        '';
      };
    };
  };
}
