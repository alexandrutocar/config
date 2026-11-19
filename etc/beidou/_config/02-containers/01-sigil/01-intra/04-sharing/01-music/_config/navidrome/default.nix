{
  sigil,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra) ip;
  inherit (lib.extra.sigil) getULA;
  inherit (lib.modules) mkMerge;
in {
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
          Address = sigil.self |> getULA |> ip.toURIHost;
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
