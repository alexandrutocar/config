{
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra) url;
  inherit (lib.extra.sigil) getULA;
in {
  services.nginx.streamConfig = let
    target = sigil.containers.intra.acda4bf3-2678-43c5-bae9-e67bd8cb710d;
  in ''
    upstream forge_ssh {
        server ${url.mkInterface (target |> getULA) 22};
    }

    server {
        listen 22;
        listen ${url.mkInterface (sigil.self |> getULA) 22};
        proxy_pass forge_ssh;
    }
  '';
}
