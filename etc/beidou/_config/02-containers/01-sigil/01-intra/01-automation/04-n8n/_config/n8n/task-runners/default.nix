{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.attrsets) attrNames attrValues;
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.strings) concatStringsSep;
in {
  systemd = {
    services = {
      n8n-task-runners = {
        serviceConfig = {
          SetCredentialEncrypted = mkSetCredentialEncrypted {
            # tr -dc 'a-f0-9' < /dev/urandom | head -c 64 | systemd-creds encrypt --with-key=host --name=runners-auth-token - -
            runners-auth-token = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAMcsrjehdohXQqU9IAAAAAZPey9v0lDesWm4I
              DBIu8o3/xQooGlCOgsxBPWGxo7bBE+AjRKnh2oXyP3xjHynEOZc0SiaCmfsJlb1erNFzg1oXt+ssmDD
              HzZHoYapcrZf0S+vpUIMiji5+Ok+Bagzxb/r0x9e/YvFFyqTVER2bV9hTtsnn6yC2m
            '';
          };
        };
      };
    };
  };

  services = {
    n8n-task-runners = {
      enable = true;
      settings = {
        launcher = {
          # The default points at n8n's credentials directory, which this unit can't see.
          auth-token-file = "${credentialsDirectory "n8n-task-runners"}/runners-auth-token";
        };

        runner = {
          python = let
            cfg = config.services.n8n-task-runners;
          in let
            # ────────────────────────────────────────────────────────────────────────
            # Python libraries available to Code nodes.
            #   key   = nixpkgs attribute in python3Packages
            #   value = top-level import name used in the Code node
            # ────────────────────────────────────────────────────────────────────────
            pythonLibraries = {
              requests = "requests";
              python-dateutil = "dateutil";
              pyyaml = "yaml";
            };

            # Standard-library modules Code nodes may import ("*" allows all).
            pythonStdlib = [
              "base64"
              "collections"
              "csv"
              "datetime"
              "hashlib"
              "itertools"
              "json"
              "math"
              "re"
              "statistics"
              "urllib"
              "uuid"
              "zoneinfo"
            ];
          in let
            python = pkgs.python3.withPackages (ps:
              [ps.websockets] # required by the runner itself to reach the broker
              ++ map (name: ps.${name}) (attrNames pythonLibraries));

            # Same as the package's own n8n-task-runner-python wrapper, but with the
            # interpreter above instead of one that only has `websockets`.
            runnerDir = "${cfg.package}/lib/n8n-task-runner-python";

            pythonRunner = pkgs.writeShellScript "n8n-task-runner-python" ''
              export PYTHONPATH=${runnerDir}
              exec ${python}/bin/python ${runnerDir}/src/main.py "$@"
            '';
          in {
            command = "${pythonRunner}";
            env-overrides = {
              N8N_RUNNERS_EXTERNAL_ALLOW = concatStringsSep "," (attrValues pythonLibraries);
              N8N_RUNNERS_STDLIB_ALLOW = concatStringsSep "," pythonStdlib;
              # Lets the allowed libraries import their own dependencies;
              # imports written in Code nodes are still checked.
              N8N_RUNNERS_ALLOW_TRANSITIVE_IMPORTS = "true";
            };
          };
        };
      };
    };
  };
}
