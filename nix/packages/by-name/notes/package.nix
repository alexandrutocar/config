{
  fetchFromGitHub,
  callPackage,
}: let
  deno2nix = let
    src = fetchFromGitHub {
      repo = "deno2nix";
      owner = "aMOPel";
      rev = "adb4dcea663cd61c19e01c8c36dd73db4af358a5";
      sha256 = "sha256-ZGKHKRB7K5aUIyJenXwOcX21F2yTXLa19q3YXQM3E48=";
    };
  in
    import src {
      pkgs = {
        inherit callPackage;
      };
    };
in let
  denoWorkspacePath = "./src/client/apps/notes";
in
  deno2nix.lib.buildDenoPackage {
    inherit denoWorkspacePath;

    pname = "notes";
    version = "0.0.1";

    src = fetchGit {
      url = "file:///home/alex/.tracked/web";
      rev = "1c8e172eea5cd11e31e5795a80b2999d1f25dddf";
    };

    env = {
      ASTRO_TELEMETRY_DISABLED = "1";
    };

    denoDepsHash = "sha256-0ZAEtiB3vqijTLhDjWi+h7x0hJPPGrR2Q5o0JlTvtPI=";

    installPhase = ''
      mkdir -p $out
      cp -r ${denoWorkspacePath}/.build/. $out/
    '';
  }
