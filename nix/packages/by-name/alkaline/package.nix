{
  bun2nix,
  stdenv,
  ...
}: let
  pname = "alkaline";
  version = "0.0.2";
in
  stdenv.mkDerivation {
    inherit pname version;

    src = fetchGit {
      url = "git@codeberg.org:alexandrutocar/${pname}.git";
      ref = "v${version}";
      rev = "ebdaab0db6f6fb6ded14e73754091023987fc3dc";
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
