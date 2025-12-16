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
  # ────────────────────────────────────────────────────────────────────────
  # NOTE: Needed to be disabled as compilation of documentation relies on
  #       upstream documentation which is removed from some packages here.
  # ────────────────────────────────────────────────────────────────────────
  documentation.nixos.enable = false;

  # NIX
  # ---
  nix = {
    # flakes supersede channels
    channel.enable = false;

    # store --optimize
    optimise = {
      automatic = true;
      dates = ["03:15"];
    };

    # nix-collect-garbage --delete-older-than 365d
    gc = {
      automatic = true;
      dates = mkDefault "03:15";
      options = mkDefault "--delete-older-than 14d";
    };

    settings = {
      keep-derivations = true;
      keep-outputs = true;

      # store --optimize (every build)
      auto-optimise-store = true;

      # flake.nix & `$ nix command`
      experimental-features = ["nix-command" "flakes" "pipe-operators"];

      # Only allow root to build
      trusted-users = ["root"];

      # re-evaluate on every rebuild instead of "cached failure of attribute" error
      eval-cache = false;
      warn-dirty = false;

      # removes ~/.nix-profile and ~/.nix-defexpr
      use-xdg-base-directories = true;

      # Binary Cache Providers
      substituters = [
        "https://cache.nixos.org"
        "https://cache.ueuie.dev"
      ];

      trusted-public-keys = [
        "cache.nixos.org:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.ueuie.dev:yx2Q390VKtD/H/8FdgBBwky6yj18sMxtufAGlUAkSSs="
      ];
    };

    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
