{
  config,
  sigil,
  pkgs,
  lib,
  ...
}: let
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
    navidrome = let
      package = pkgs.navidrome.withPlugins (
        plugins:
          with plugins; [
            listenbrainz-daily-playlist
          ]
      );
    in {
      inherit package;

      enable = true;

      settings = mkMerge [
        {
          DataFolder = "/var/lib/navidrome";
          Address = "[${sigil.self.addresses.ula}]";
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
