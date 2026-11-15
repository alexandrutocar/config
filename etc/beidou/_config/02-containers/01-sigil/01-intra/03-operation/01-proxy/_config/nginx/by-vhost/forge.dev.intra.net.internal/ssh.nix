{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra) url;
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
        server ${url.mkInterface sigil.containers.intra."acda4bf3-2678-43c5-bae9-e67bd8cb710d".addresses.ipv6.ula 22};
    }

    server {
        listen 22;
        listen ${url.mkInterface sigil.self.addresses.ipv6.ula 22};
        proxy_pass forge_ssh;
    }
  '';
}
