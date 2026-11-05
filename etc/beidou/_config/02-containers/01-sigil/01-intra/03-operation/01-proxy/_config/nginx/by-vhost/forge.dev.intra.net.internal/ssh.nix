{sigil, ...}: {
  networking = {
    firewall = {
      allowedTCPPorts = [
        22 # SSH
      ];
    };
  };

  services.nginx.streamConfig = ''
    upstream forge_ssh {
        server [${sigil.containers.intra."acda4bf3-2678-43c5-bae9-e67bd8cb710d".addresses.ula}]:22;
    }

    server {
        listen 22;
        listen [${sigil.self.addresses.ula}]:22;
        proxy_pass forge_ssh;
    }
  '';
}
