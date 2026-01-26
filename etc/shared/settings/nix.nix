# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █ ▀▄▀
# █░▀█ █ █░█
#
# nix daemon, garbage collection, store optimization...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  # NIX
  # ---
  nix = {
    # flakes supersede channels
    channel.enable = mkDefault false;

    # store --optimize
    optimise = {
      automatic = mkDefault true;
      dates = mkDefault ["03:15"];
    };

    # nix-collect-garbage --delete-older-than 365d
    gc = {
      automatic = true;
      dates = mkDefault "03:15";
      options = mkDefault "--delete-older-than 14d";
    };

    settings = {
      # store --optimize (every build)
      auto-optimise-store = mkDefault true;

      # flake.nix & `$ nix command`
      experimental-features = mkDefault ["nix-command" "flakes" "pipe-operators"];

      # Only allow root to build
      trusted-users = mkDefault ["root"];

      # re-evaluate on every rebuild instead of "cached failure of attribute" error
      eval-cache = mkDefault false;
      warn-dirty = mkDefault false;

      # removes ~/.nix-profile and ~/.nix-defexpr
      use-xdg-base-directories = mkDefault true;

      substituters = mkDefault [
        "https://cache.ueuie.dev"
      ];

      trusted-public-keys = mkDefault [
        "cache.ueuie.dev:yx2Q390VKtD/H/8FdgBBwky6yj18sMxtufAGlUAkSSs="
      ];
    };

    extraOptions = mkDefault ''
      builders-use-substitutes = true
    '';
  };
}
