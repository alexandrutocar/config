{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.ip) toCompressed;
  inherit (lib.extra.url) mkAuthority;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        22 # SSH
      ];
    };
  };

  services.nginx.streamConfig = ''
    upstream forge_ssh {
        server ${mkAuthority (sigil.containers.intra."acda4bf3-2678-43c5-bae9-e67bd8cb710d".addresses.ula |> toCompressed) 22 {}};
    }

    server {
        listen 22;
        listen ${mkAuthority (sigil.self.addresses.ula |> toCompressed) 22 {}};
        proxy_pass forge_ssh;
    }
  '';
}
