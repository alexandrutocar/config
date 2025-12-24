{
  stdenv,
  bun2nix,
  ...
}:
stdenv.mkDerivation {
  pname = "alkaline";
  version = "0.0.1";

  src = ../alkaline;

  strictDeps = true;

  nativeBuildInputs = [
    bun2nix.hook
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.lock.nix;
  };

  buildPhase = ''
    runHook preBuild

    bun run build --minify

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -R .output $out

    runHook postInstall
  '';
}
