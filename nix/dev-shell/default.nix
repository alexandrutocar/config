{
  mkShell,
  fetchFromGitHub,
  rustPlatform,
  ...
} @ pkgs:
mkShell {
  buildInputs = with pkgs; [
    shellcheck
    alejandra

    deadnix
    vulnix

    nixd
    shfmt
    statix

    opentofu
  ];
}
