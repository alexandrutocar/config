{
  config,
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) ipv6;
  inherit (lib.modules) mkMerge;
in {
  networking = {
    firewall = {
      allowedTCPPorts = [
        config.services.navidrome.settings.Port # HTTP
      ];
    };
  };

  services = {
    navidrome = {
      enable = true;
      plugins = with pkgs.navidromePlugins; [
        listenbrainz-daily-playlist
      ];

      settings = mkMerge [
        {
          DataFolder = "/var/lib/navidrome";
          Address = ipv6.enclose sigil.self.addresses.ula;
          Port = 8080;
        }
        {
          MusicFolder = "/mnt/audio/music";
          DefaultLanguage = "de";
          AlbumPlayCountMode = "normalized";
        }
      ];
    };
  };
}
