{
  description = ''
    Nix Systems' Configuration
  '';

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?rev=7e728862960bcb3e21520807bd6db5f968ee4079"; # nixos-unstable-small
    };

    # ────────────────────────────────────────────────────────────────────────

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    harmonia = {
      url = "github:nix-community/harmonia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (lib.filesystem) packagesFromDirectoryRecursive;
    inherit (lib.attrsets) attrValues genAttrs;
    inherit (lib.extra.attrsets) mergeAttrsList;

    forSystems = genAttrs [
      "x86_64-linux"
    ];

    mkPackages = system: pkgs:
      import pkgs {
        inherit system;

        overlays = attrValues self.overlays;
      };

    lib = inputs.nixpkgs.lib.extend (final: super: ((import (self + /nix/lib) final super) // inputs.home-manager.lib));

    mkSystem = hostname: {
      nixpkgs,
      modules,
    }:
      lib.nixosSystem {
        modules =
          [
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote

            # Custom options.
            ./nix/nixos/modules

            # Make `nix run nixpkgs#nixpkgs` use the same
            # package repository as the one used here.
            {
              nix.registry.nixpkgs.flake = lib.mkForce nixpkgs;
            }

            # Ensure device has expected name in wireless, wired and bluetooth networks.
            {
              networking.hostName = hostname;
              hardware.bluetooth.settings.General.Name = hostname;
            }

            # Cross-system package overlays.
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
    # `nix develop`
    devShells = forSystems (system: let
      pkgs = mkPackages system inputs.nixpkgs;
    in {
      default = import ./nix/dev-shell/default.nix pkgs;
    });

    # `nix fmt`
    formatter = forSystems (
      system: (mkPackages system inputs.nixpkgs).alejandra
    );

    overlays = let
      inherit (lib.extra.files.special) patches scripts;
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

    nixosConfigurations = {
      aether = let
        inherit (inputs) nixpkgs;
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
                ./dot/aether/git
              ];
            });
        };

      albedo = let
        inherit (inputs) nixpkgs;
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
                ./dot/albedo/alex
              ];
            });
        };
    };

    packages = forSystems (
      system: let
        pkgs = mkPackages system inputs.nixpkgs;
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
                inherit (inputs) nixpkgs;
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
                      user = "yelan";
                      spec = [
                        ./dot/beidou/yelan
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
