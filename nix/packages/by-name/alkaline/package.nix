{
  bun2nix,
  stdenv,
  ...
}: let
  pname = "alkaline";
  version = "0.0.3";
in
  stdenv.mkDerivation {
    inherit pname version;

    src = fetchGit {
      url = "git@codeberg.org:alexandrutocar/${pname}.git";
      ref = "v${version}";
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
  }
