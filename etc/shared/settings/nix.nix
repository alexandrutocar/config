# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ █ ▀▄▀
# █░▀█ █ █░█
#
# nix daemon, garbage collection, store optimization...
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.modules) mkDefault mkForce;
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

    settings = {
      # store --optimize (every build)
      auto-optimise-store = mkDefault true;

      # flake.nix & `$ nix command`
      experimental-features = mkDefault ["ca-derivations" "flakes" "nix-command" "no-url-literals" "parse-toml-timestamps" "pipe-operators"];

      # Only allow root to build
      trusted-users = mkDefault ["root"];

      # re-evaluate on every rebuild instead of "cached failure of attribute" error
      eval-cache = mkDefault false;
      warn-dirty = mkDefault false;
 
      # removes ~/.nix-profile and ~/.nix-defexpr
      use-xdg-base-directories = mkDefault true;

      substituters = [
        "https://cache.aether.ip"
      ];

      trusted-public-keys = [
        "cache.aether.ip:YJj654vefxddqk3R5eEyDzFQXw6hDmVkJKVvxAqHnj4="
      ];
    };

    extraOptions = mkDefault ''
      builders-use-substitutes = true
    '';
  };
}
