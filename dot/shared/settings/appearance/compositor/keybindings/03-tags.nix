{lib, ...}: {
  wayland.windowManager.river.settings = let
    inherit (lib.attrsets) recursiveUpdate;
    inherit (lib.lists) foldl';

    inherit (lib.extra.math) pow seq;
  in
    foldl' recursiveUpdate {} [
      {
        map.normal = foldl' recursiveUpdate {} [
          (foldl' recursiveUpdate {} (
            map (
              i: let
                key = ''"${toString i}"'';
                tag = toString (pow 2 (i - 1));
              in {
                # # Super [1-9] to focus tag [0-8]
                "Super ${key}" = "set-focused-tags ${tag}";

                # Super+Shift [1-9] to tag focused view with tag [0-8]
                "Super+Shift ${key}" = "set-view-tags ${tag}";

                # Super+Control [1-9] to toggle focus of tag [0-8]
                "Super+Control ${key}" = "toggle-focused-tags ${tag}";

                # Super+Shift+Control [1-9] to toggle tag [0-8] of focused view
                "Super+Shift+Control ${key}" = "toggle-view-tags ${tag}";
              }
            ) (seq 1 9)
          ))
        ];
      }
      (let
        tag = toString ((pow 2 32) - 1);
      in {
        # Super 0 to focus all tags
        "Super 0" = "set-focused-tags ${tag}";

        # Super+Shift 0 to tag focused view with all tags
        "Super+Shift 0" = "set-view-tags ${tag}";
      })
    ];
}
