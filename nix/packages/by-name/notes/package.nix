{
  fetchFromForgejo,
  fetchFromGitHub,
  callPackage,
  certs,
  brotli,
  gzip,
  fd,
  lib,
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
  notes = let
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
    };
in
  lib.extendDerivation true {
    caddy = let
      importBlock = "notes_config";
      extraConfig = ''
        (${importBlock}) {
          root * ${notes}

          # Content Negotiation
          @index-md {
            header_regexp Accept text/markdown
            path /
          }

          @md {
            header_regexp Accept text/markdown

            # Notes
            path /en/notes /en/notes/*
            path /de/notizen /de/notizen/*
          }

          route @md {
            uri strip_suffix /
            rewrite * {path}.md
            header Content-Type "text/markdown; charset=utf-8"
            file_server { precompressed br gzip zstd }
          }

          route @index-md {
            rewrite * index.md
            header Content-Type "text/markdown; charset=utf-8"
            file_server { precompressed br gzip zstd }
          }

          # Hashed Assets
          header /_astro/* Cache-Control "public, max-age=31536000, immutable"

          # HTML Pages
          header ?Cache-Control "no-cache"

          # Icons
          @icons path /favicon.svg /img/icons/*
          header @icons Cache-Control "max-age=3600, must-revalidate"

          # Redirects
          @en path /en /en/
          redir @en /en/notes 301

          @de path /de /de/
          redir @de /de/notizen 301

          # Compression
          encode zstd gzip
          file_server { precompressed br gzip zstd }

          # Error Handling
          handle_errors {
            @404 { expression {http.error.status_code} == 404 }
            rewrite @404 /404.html
            file_server { precompressed br gzip zstd }
          }
        }
      '';
    in {
      inherit importBlock extraConfig;
    };
  }
  notes
