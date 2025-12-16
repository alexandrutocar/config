{pkgs, ...}: {
  languages = {
    nix.enable = true;
    shell.enable = true;
  };

  git-hooks.hooks = {
    flake-checker = {
      enable = true;
    };

    alejandra = {
      enable = true;
      settings = {
        exclude = [
          ".doc"
          ".pki"
        ];
      };
    };

    statix = {
      enable = true;

      package = with pkgs; (statix.overrideAttrs (_: let
        src = fetchFromGitHub {
          owner = "oppiliappan";
          repo = "statix";
          rev = "e9df54ce918457f151d2e71993edeca1a7af0132";
          hash = "sha256-duH6Il124g+CdYX+HCqOGnpJxyxOCgWYcrcK0CBnA2M=";
        };
      in {
        inherit src;

        cargoDeps = rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
          allowBuiltinFetchGit = true;
        };
      }));

      settings = {
        ignore = [
          ".doc"
          ".pki"
        ];
      };
    };

    trufflehog = {
      enable = true;

      # ERROR:  > trufflehog --version
      #         trufflehog 3.91.2
      # package = with pkgs; (trufflehog.overrideAttrs (_: let
      #   version = "3.92.3";

      #   src = fetchFromGitHub {
      #     owner = "trufflesecurity";
      #     repo = "trufflehog";
      #     tag = "v${version}";
      #     hash = "sha256-vSJncJzHxiZqDG0BQrLUjU7mFvZ6PnoE2FkITRvKmes=";
      #   };
      # in {
      #   inherit src version;
      #   vendorHash = "sha256-Qz0tKqqT3PlZFCiYxLBmHeICIx2ogOUW7rfXHadcVPg=";
      #   doInstallCheck = false;
      # }));
    };
  };
}
