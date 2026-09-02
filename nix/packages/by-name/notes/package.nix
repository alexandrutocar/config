{
  fetchFromForgejo,
  fetchFromGitHub,
  callPackage,
  certs,
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
    version = "unstable-2026083104";

    src = fetchFromForgejo {
      domain = "forge.dev.intra.net.internal";
      owner = "alex";
      repo = "web";
      rev = "6649ed43fe30eb6836c447e32e3403393f39363c";
      hash = "sha256-vtpSo6OR6nACXPnhihzKrMPAr4oukJyqE58dybVaNis=";
      curlOptsList = ["--cacert" "${certs}/etc/ssl/anchor/intra.net.pem"];
    };

    env = {
      ASTRO_TELEMETRY_DISABLED = "1";
    };

    denoDepsHash = "sha256-2ttUoNWk+4PDWAKsRMgNlNponxr6oeFYp0mSkGVZuqQ=";

    installPhase = ''
      cp -r ${denoWorkspacePath}/.build/. $out/
    '';
  }
