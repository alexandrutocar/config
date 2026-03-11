# ────────────────────────────────────────────────────────────────────────
#
# █▀█ █▀█ █▀ ▀█▀ █▀▀ █▀█ █▀▀ █▀ █▀█ █░░
# █▀▀ █▄█ ▄█ ░█░ █▄█ █▀▄ ██▄ ▄█ ▀▀█ █▄▄
#
# postgresql, databases, authentication...
#
# ────────────────────────────────────────────────────────────────────────
{
  container,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (container) self intranet-database;
in {
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "terraform"
  # ];

  # virtualisation.docker = {
  #   enable = true;
  # };

  # users.users.coder.extraGroups = [ config.users.groups.docker.name ];

  # services.coder = {
  #   enable = true;
  #   environment = {
  #     CODER_ACCESS_URL = "https://coder.aether.ip";
  #     CODER_WILDCARD_ACCESS_URL = "*.coder.aether.ip";
  #     CODER_HTTP_ADDRESS = "${self.localAddress}:8080";
  #     CODER_PG_CONNECTION_URL = "postgres://coder@${intranet-database.localAddress}:5432/coder?sslmode=disable";
  #   };
  # };
}
