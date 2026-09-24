{
  config,
  sigil,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6 mkHost;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        8080 # HTTP
      ];
    };
  };

  services = {
    gonic = {
      enable = true;
      settings = {
        scan-watcher-enabled = true;

        listen-addr = mkHost (ipv6.enclose sigil.self.addresses.ula) 8080;

        db-path = "/var/lib/gonic/gonic.db";
        cache-path = "/var/cache/gonic";

        music-path = ["/mnt/audio/music"];
        podcast-path = "/mnt/audio/podcast";
        playlists-path = "/mnt/audio/playlists";

        multi-value-isrc = "multi";
        multi-value-genre = "multi";
        multi-value-artist = "multi";

        multi-value-album-artist = "multi";

      };
    };
  };
}
