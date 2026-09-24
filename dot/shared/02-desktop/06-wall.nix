{
  config,
  pkgs,
  ...
}: {
  services = {
    wbg = let
      package = pkgs.wbg.override {
        enableJPEG = false;
        enableWebp = false;
      };
    in {
      inherit package;

      enable = true;

      image = "${config.home.homeDirectory}/.wallpapers/sunflowers-from-my-neighbor-totoro.png";
    };
  };

  systemd.user.services = {
    wbg = {
      Service = {
        Slice = ["session-graphical.slice"];
      };
    };
  };
}
