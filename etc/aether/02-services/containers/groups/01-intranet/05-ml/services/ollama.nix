{
  container,
  pkgs,
  lib,
  ...
}: let
  inherit (container) self;
in {
  services.ollama = {
    enable = true;

    # Hardware
    package = pkgs.ollama-cuda.override {
      cudaArches = ["61"];
    };

    # Network
    host = self.localAddress;
    port = 8080;

    # Storage
    modelsDir = "/var/lib/models";
  };

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "cuda_cudart"
      "cuda_nvcc"
      "cuda_cccl"
      "libcublas"
    ];
}
