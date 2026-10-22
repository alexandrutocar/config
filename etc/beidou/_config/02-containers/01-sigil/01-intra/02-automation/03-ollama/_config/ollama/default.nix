{
  hostConfig,
  config,
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [config.services.ollama.port];
    };
  };

  systemd.tmpfiles.settings = {
    "10-nvidia" = {
      "/run/opengl-driver" = {
        "L+" = {
          argument = toString hostConfig.hardware.nvidia.package.out;
        };
      };
    };
  };

  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
  };
  users.groups.ollama = {};

  services = {
    ollama = {
      enable = true;

      package = pkgs.ollama-cuda;

      host = ipv6.enclose sigil.self.addresses.ula;
      port = 11434;

      user = "ollama";
      group = "ollama";

      modelsDir = "/var/lib/models";
      loadModels = [
        "qwen3.5:2b"
        "qwen3.5:4b"
      ];
    };
  };
}
