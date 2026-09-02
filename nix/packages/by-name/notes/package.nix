{
  fetchFromForgejo,
  fetchFromGitHub,
  callPackage,
  certs,
  brotli,
  gzip,
  fd,
  zstd,
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

    nativeBuildInputs = [
      brotli
      gzip
      fd
      zstd
    ];

    installPhase = ''
      pushd ${denoWorkspacePath}/.build

      echo "Sidecar files generation started."

      TARGET_FILES=$(
      	fd --type f --exec file --mime-type {} + |
      		grep -E "text/|javascript|json|xml|svg|font/(ttf|otf)" |
      		cut -d: -f1
          fd --type f --extension ttf --extension otf |
              sort -u
      )

      if [ -z "$TARGET_FILES" ]; then
      	echo "Could not find any compressable text-assets."
      else
      	echo "Generate Brotli..."
      	echo "$TARGET_FILES" | xargs -P 0 -I {} brotli -q 11 -w 24 -f -k "{}" -o "{}.br"

      	echo "Generate Gzip..."
      	echo "$TARGET_FILES" | xargs -P 0 -I {} gzip -9 -k -f "{}"

      	echo "Generate Zstd..."
      	echo "$TARGET_FILES" | xargs -P 0 -I {} zstd --ultra -22 -k -f "{}" -o "{}.zst"
      fi

      echo "Sidecar files generation completed."

      popd

      cp -r ${denoWorkspacePath}/.build/. $out/
    '';
  }
