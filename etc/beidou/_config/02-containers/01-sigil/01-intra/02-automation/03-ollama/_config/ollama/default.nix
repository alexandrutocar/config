{
  hostConfig,
  config,
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.ip) toURIHost;
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

      host = sigil.self.addresses.ula |> toURIHost;
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
