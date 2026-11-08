{
  description = ''
    Reproducible configuration for Albedo (Client), Beidou (Server/On-Premise), Collei (Server/VPS) and Fischl (Server/On-Premise).
  '';

  inputs = {
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For server systems (hosts).
    # ────────────────────────────────────────────────────────────────────────
    nixos-unstable-small = {
      url = "github:nixos/nixpkgs/nixos-unstable-small";
    };

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For desktop-oriented systems (workstations) and software
    #       with long build times (e.g. Firefox, Chromium, Electron).
    # ────────────────────────────────────────────────────────────────────────
    nixos-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    # ────────────────────────────────────────────────────────────────────────
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        nixpkgs.follows = "nixos-unstable";
        home-manager.follows = "";
      };
    };

    "dns.nix" = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixos-unstable-small";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs = {
        nixpkgs.follows = "nixos-unstable-small";

        # Consumed by nix,nixd,git-hooks
        flake-compat.follows = "";
        flake-parts.follows = "";

        # Consumed by devenv (package)
        crate2nix.follows = "";
        ghostty.follows = "";
        nix.follows = "";
        nixd.follows = "";
        rust-overlay.follows = "";
      };
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs = {
        nixpkgs.follows = "nixos-unstable-small";
        pre-commit.follows = "";
      };
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (lib.attrsets) attrValues genAttrs mergeAttrsList;
    inherit (lib.filesystem) packagesFromDirectoryRecursive;
    inherit (lib.lists) concatLists singleton;
    inherit (lib.extra.files.list) recursive;
    inherit (lib.extra.files.special) patches scripts;
    inherit (lib.path) append;
    inherit (lib.strings) concatStringsSep;

    # Library
    # -------
    libOverlay = final: prev:
      import ./nix/libraries final prev
      // {
        dns = inputs."dns.nix".lib;
      };

    # `nixpkgs.lib.extend` (rather than `//`) keeps flake-only attributes such
    # as `nixosSystem` and makes them evaluate with the extended lib.
    mkLib = nixpkgs: nixpkgs.lib.extend libOverlay;

    # Used only to evaluate this file; hosts get their own lib through mkSystem.
    lib = mkLib inputs.nixos-unstable-small;
  in let
    # Systems
    # -------
    forEachSystem = let
      systems = [
        "x86_64-linux"
      ];
    in
      func:
        genAttrs systems (system:
          func (import inputs.nixos-unstable-small {
            inherit system;
            # ────────────────────────────────────────────────────────────────────────
            # NOTE: This applies all overlays defined at self.overlays
            # ────────────────────────────────────────────────────────────────────────
            overlays = attrValues self.overlays;
          }));
  in let
    # Packages
    # --------
    byName = callPackage:
      packagesFromDirectoryRecursive {
        inherit callPackage;
        directory = ./nix/packages/by-name;
      };
  in {
    devShells = forEachSystem (pkgs: {
      default = inputs.devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          (_: {
            languages = {
              nix = {
                enable = true;
              };

              shell = {
                enable = true;
              };
            };

            git-hooks = {
              hooks = {
                # nix
                alejandra = {
                  enable = true;
                };

                deadnix = {
                  enable = true;
                };

                statix = {
                  enable = true;
                  settings = {
                    config = let
                      tomlFormat = pkgs.formats.toml {};
                    in
                      toString (
                        tomlFormat.generate "statix.toml" {
                          disabled = [
                            "collapsible_let_in"
                          ];
                        }
                      );
                  };
                };

                # shell
                shfmt = {
                  enable = true;
                };

                shellcheck = {
                  enable = true;
                };
              };
            };
          })
        ];
      };
    });

    formatter = forEachSystem ({alejandra, ...}: alejandra);

    nixosConfigurations = let
      _mkSystemFactory = nixpkgs: let
        lib = mkLib nixpkgs;
      in
        hostName: extraModules:
          lib.nixosSystem {
            modules = concatLists [
              # External Modules
              # ----------------
              (with inputs; [
                impermanence.nixosModules.impermanence
                lanzaboote.nixosModules.lanzaboote
              ])

              # Custom Modules
              # --------------
              (recursive ./nix/modules/nixos)

              # Extra Modules
              # -------------
              extraModules

              # Host Config
              # -----------
              (singleton (append ./etc hostName))

              # Nixpkgs Configuration
              # ---------------------
              (singleton {
                nixpkgs = {
                  # ────────────────────────────────────────────────────────────────────────
                  # NOTE: This applies all overlays defined at self.overlays
                  # ────────────────────────────────────────────────────────────────────────
                  overlays = attrValues self.overlays;
                };
              })
            ];

            specialArgs = {
              inherit lib self inputs hostName;
            };
          };
    in let
      mkEndpointSystem = _mkSystemFactory inputs.nixos-unstable;

      mkHeadlessServer = _mkSystemFactory inputs.nixos-unstable-small;
    in let
      mkHome = userList: {
        imports = concatLists [
          # Home-Manager Module
          # -------------------
          (with inputs; [
            home-manager.nixosModules.home-manager
          ])

          # General Config
          # --------------
          (singleton (
            {hostName, ...}: {
              home-manager = {
                useUserPackages = true;

                useGlobalPkgs = true;

                users = mergeAttrsList userList;

                sharedModules = recursive ./nix/modules/home-manager;

                extraSpecialArgs = {
                  inherit self inputs hostName;
                };
              };
            }
          ))
        ];
      };

      mkUser = username: {
        ${username} = {hostName, ...}: {
          imports = singleton (append ./dot (concatStringsSep "/" [hostName username]));

          _module = {
            args = {inherit username;};
          };
        };
      };
    in {
      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Client systems with desktop environment and enduser applications.
      # ────────────────────────────────────────────────────────────────────────
      albedo = mkEndpointSystem "albedo" [
        (mkHome [
          (mkUser "alex")
        ])
      ];

      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Server systems with no graphical interface (running containers).
      # ────────────────────────────────────────────────────────────────────────
      beidou = mkHeadlessServer "beidou" [];

      collei = mkHeadlessServer "collei" [];

      fischl = mkHeadlessServer "fischl" [];
    };

    overlays = let
      fixes = append ./nix "fixes?";
    in
      {
        packages = final: _: byName final.callPackage;

        lib = _: prev: {
          lib = prev.lib.extend libOverlay;
        };

        tools = final: _: {
          custom = {
            writeAuthZone = import ./nix/packages/tools/write-auth-zone/package.nix final;
            writeShell = import ./nix/packages/tools/write-shell/package.nix final;
            scripts = scripts ./nix/packages/scripts final;
          };

          dns.util = inputs."dns.nix".util.${final.stdenv.hostPlatform.system};
        };

        formats = final: prev: {
          formats =
            prev.formats
            // genAttrs [
              "plist"
              "kdl"
              "strongswan"
            ] (name: import (append ./nix/packages/formats "${name}.nix") final);
        };
      }
      // patches fixes;

    packages = forEachSystem (pkgs: byName pkgs.callPackage);
  };
}
