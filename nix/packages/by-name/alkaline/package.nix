{
  bun2nix,
  stdenv,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "alkaline";
  version = "0.0.3";

  src = fetchGit {
    url = "git@codeberg.org:alexandrutocar/${finalAttrs.pname}.git";
    ref = "v${finalAttrs.version}";
    rev = "7f447a118284f05af3027de59a8720e226601bd8";
  };

  strictDeps = true;

  nativeBuildInputs = [
    bun2nix.hook
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.lock.nix;
  };

  buildPhase = ''
    bun run build --minify
  '';

  installPhase = ''
    mkdir -p $out
    cp -r .output/* $out/
  '';
})
