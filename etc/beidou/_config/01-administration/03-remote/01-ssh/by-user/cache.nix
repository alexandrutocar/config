_: let
  user.name = "cache";
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
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHUn9Mp/Jj1cPjZuc/PuLOJN8Kcu8QybIzWeC4KcxaMQ alex@albedo"
      ];
    };
  };
}
