{
  description = ''
    Systems configuration files.
  '';

  inputs = {
    # ────────────────────────────────────────────────────────────────────────
    # I am using determinate Nix because of its optimized evaluation
    # algorithm, faster standard library and attested security guarantees.
    # ────────────────────────────────────────────────────────────────────────
    determinate = {
      url = "github:determinatesystems/determinate";
    };

    # ────────────────────────────────────────────────────────────────────────
    # This package set is pinned to a commit of a patched `unstable-small`
    # branch of [nixpkgs](https://github.com/nixos/nixpkgs). It is rebased
    # regularly to keep up with the upstream - usually weekly, sometimes in
    # longer intervals.
    # ────────────────────────────────────────────────────────────────────────
    packages = {
      url = "git+https://codeberg.org/alexandrutocar/packages?rev=63527c28712c6ff8475e31fe952394844989e0f3";
    };

    # ────────────────────────────────────────────────────────────────────────
    # These are additional modules simplifying:
    # - hardware configuration management
    # - generation of bootable systems (including virtual machines)
    # - symlinking of files and directories for the purpose of persistence
    # - utility for signing generations and managing keys for the secure boot
    # - binary cache server
    # - user configuration management (.dotfiles)
    # ────────────────────────────────────────────────────────────────────────
    nixos-facter-modules = {
      url = "github:nix-community/nixos-facter-modules";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "packages";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "packages";
    };

    harmonia = {
      url = "github:nix-community/harmonia";
      inputs.nixpkgs.follows = "packages";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "packages";
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (lib.filesystem) packagesFromDirectoryRecursive;
    inherit (lib.attrsets) attrValues genAttrs;
    inherit (lib.custom.attrsets) mergeAttrsList;
    inherit (lib.strings) getName;

    forSystems = genAttrs [
      "x86_64-linux"
    ];

    mkPackages = system: pkgs:
      import pkgs {
        inherit system;
        overlays = attrValues self.overlays;
      };

    lib = inputs.packages.lib.extend (final: super: ((import (self + /nix/lib) final super) // inputs.home-manager.lib));

    mkSystem = hostname: {
      nixpkgs,
      modules,
    }:
      lib.nixosSystem {
        modules =
          [
            inputs.nixos-facter-modules.nixosModules.facter
            inputs.impermanence.nixosModules.impermanence
            inputs.determinate.nixosModules.default
            inputs.lanzaboote.nixosModules.lanzaboote

            # Custom options.
            ./nix/nixos/modules

            # Make `nix run nixpkgs#nixpkgs` use the same
            # package repository as the one used here.
            {
              nix.registry.nixpkgs.flake = lib.mkForce nixpkgs;
            }

            # Ensure relevant system parts have
            # the specified name.
            {
              networking.hostName = hostname;
              hardware.bluetooth.settings.General.Name = hostname;
            }

            # Cross-system package overlays and prefixes of allowed unfree packages.
            {
              nixpkgs.overlays = attrValues self.overlays;
            }

            {
              system.stateVersion = "25.11";
            }
          ]
          ++ modules;
        specialArgs = {
          inherit lib self inputs;
        };
      };

    mkHome = {
      user,
      spec ? [],
    }: [
      inputs.home-manager.nixosModules.home-manager
      (_: {
        home-manager = {
          sharedModules = [
            # Custom options.
            ./nix/hm/modules
          ];

          useUserPackages = true;
          useGlobalPkgs = true;

          extraSpecialArgs = {
            inherit lib self inputs;
          };

          users.${user} = _: {
            imports = spec;
          };
        };
      })
    ];
  in {
    # `nix develop --no-pure-eval` (https://direnv.sh)
    devShells = forSystems (system: let
      pkgs = mkPackages system inputs.packages;
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          alejandra
          nil
          (
            statix.overrideAttrs (_: let
              src = fetchFromGitHub {
                owner = "oppiliappan";
                repo = "statix";
                rev = "e9df54ce918457f151d2e71993edeca1a7af0132";
                hash = "sha256-duH6Il124g+CdYX+HCqOGnpJxyxOCgWYcrcK0CBnA2M=";
              };
            in {
              inherit src;

              cargoDeps = rustPlatform.importCargoLock {
                lockFile = "${src}/Cargo.lock";
                allowBuiltinFetchGit = true;
              };
            })
          )
        ];
      };
    });

    # `nix fmt` (https://kamadorueda.com/alejandra)
    formatter = forSystems (
      system: (mkPackages system inputs.packages).alejandra
    );

    overlays = let
      inherit (lib.custom.files.special) patches scripts;
    in
      {
        aliases = import (./nix + "/fixes?/aliases.nix");

        custom = final: super: {
          custom =
            {
              scripts = {
                desktop = scripts ./nix/packages/scripts/desktop final;
                extras = scripts ./nix/packages/scripts/extras final;
              };
            }
            // self.packages.${final.stdenv.hostPlatform.system}
            // {
              writeShell = import ./nix/packages/utils/write-shell/package.nix final;
            };
        };
      }
      // (patches (./nix + "/fixes?"));

    # https://wiki.nixos.org/wiki/NixOS_system_configuration
    nixosConfigurations = {
      aether = let
        nixpkgs = inputs.packages;
      in
        mkSystem "aether" {
          inherit nixpkgs;
          modules =
            [
              ./etc/aether
            ]
            ++ (mkHome {
              user = "git";
              spec = [
                ./dot/aether
              ];
            });
        };

      albedo = let
        nixpkgs = inputs.packages;
      in
        mkSystem "albedo" {
          inherit nixpkgs;
          modules =
            [
              ./etc/albedo
            ]
            ++ (mkHome {
              user = "alex";
              spec = [
                ./dot/albedo
              ];
            });
        };
    };

    # https://wiki.nixos.org/wiki/Creating_a_NixOS_live_CD
    packages = forSystems (
      system: let
        pkgs = mkPackages system inputs.packages;
      in
        mergeAttrsList [
          (
            packagesFromDirectoryRecursive {
              inherit (pkgs) callPackage;
              directory = ./nix/packages/by-name;
            }
          )
          {
            beidou = let
              _system = let
                nixpkgs = inputs.packages;
              in
                mkSystem "beidou" {
                  inherit nixpkgs;
                  modules =
                    [
                      {
                        nixpkgs.hostPlatform = system;
                      }
                      ./etc/beidou
                    ]
                    ++ (mkHome {
                      user = "alex";
                      spec = [
                        ./dot/beidou
                      ];
                    });
                };
            in
              inputs.nixos-generators.nixosGenerate {
                inherit system;

                format = "iso";

                inherit (_system._module.args) modules;
                inherit (_system._module) specialArgs;
              };
          }
        ]
    );
  };
}
