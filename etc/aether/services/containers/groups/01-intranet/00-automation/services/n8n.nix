{container, lib, ...}: let 
  inherit (container) self;
in {
  services.n8n = {
    enable = true;
    environment = {
      N8N_LISTEN_ADDRESS = self.localAddress;
      N8N_HOST = "workflows.aether.ip";
      N8N_PORT = 8080;
      N8N_ENCRYPTION_KEY_FILE = "/etc/secrets/n8n/encryption.key.txt";
      WEBHOOK_URL = "https://workflows.aether.ip";
    };
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "n8n"
  ];
}
