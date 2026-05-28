{lib, ...}: {
  services.fnott = {
    enable = true;
    settings = let
      inherit (lib.extra.colors) hexToPlain;
    in let
      shared = {
        # Progress
        progress-color = hexToPlain "#232323ff";
        progress-bar-height = 10;

        # Padding
        padding-horizontal = 20;
        padding-vertical = 10;

        # Style
        background = hexToPlain "#000000ff";

        # Font
        title-font = "Tamsyn:size=15";
        body-font = "Tamsyn:size=15";
        summary-font = "Tamsyn:size=15";
        border-color = hexToPlain "#aaaaaaff";
      };
    in {
      main = {
        min-width = 250;
        progress-style = "background";
      };

      low = shared // {};

      normal = shared // {};

      critical = shared // {};
    };
  };
}
