{
  mkShell,
  fetchFromGitHub,
  rustPlatform,
  ...
} @ pkgs: mkShell {
  buildInputs = let 
    statix = pkgs.statix.overrideAttrs (_: let
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
        });
  in with pkgs; [
    shellcheck
    alejandra
    
    deadnix
    vulnix

    nixd
    shfmt
    statix
  ];
}