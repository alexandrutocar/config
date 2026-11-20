{
  sigil,
  self,
  lib,
  ...
}: let
  inherit (lib.extra) url;
  inherit (lib.extra.sigil) getULA shortPathToContainers;
in let
  fischlContainers = shortPathToContainers self.nixosConfigurations.fischl.config;
in {
  services = {
    nginx = {
      streamConfig = let
        server = let
          target = fischlContainers.porti.ea3680ca-4e51-4e86-b467-7f85d573834e;
        in
          url.mkInterface (target |> getULA) 22;

        listen = url.mkInterface sigil.self.addresses.ipv6.extra.gua.forge 22;
      in ''
        upstream forge_ssh {
          server ${server};
        }

        server {
          listen 22;
          listen ${listen};

          proxy_pass forge_ssh;
        }
      '';
    };
  };
}
