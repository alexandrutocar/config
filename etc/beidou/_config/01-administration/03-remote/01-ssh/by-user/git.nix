_: let
  user.name = "git";
in {
  services.openssh.extraConfig = ''
    Match user ${user.name}
      PermitTTY no

      AllowAgentForwarding no
      AllowTcpForwarding no
      X11Forwarding no
  '';

  users.users = {
    ${user.name} = {
      extraGroups = ["ssh"];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+Hv86vvA3XpfouF6a2w84MRIjTZVHfGZsOzbpEG6K5 alex@albedo"
      ];
    };
  };
}
