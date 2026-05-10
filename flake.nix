{
  description = ''
    Aleks' Omnium Config 
  '';

  inputs = {
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For server systems (hosts).
    # ────────────────────────────────────────────────────────────────────────
    nixpkgs-nixos-unstable-small = {
      url = "github:nixos/nixpkgs?rev=1c5503ba41146fb6b49ed9706823b30de7f3a78f"; # nixos-unstable-small
    };

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For desktop-oriented systems (workstations) and software
    #       with long build times (e.g. Firefox, Chromium, Electron).
    # ────────────────────────────────────────────────────────────────────────
    nixpkgs-nixos-unstable = {
      url = "github:nixos/nixpkgs?rev=549bd84d6279f9852cae6225e372cc67fb91a4c1"; # nixos-unstable
    };

    # ────────────────────────────────────────────────────────────────────────

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
    };

    harmonia = {
      url = "github:nix-community/harmonia";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
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

    lib = inputs.nixpkgs-nixos-unstable-small.lib.extend (final: super: ((import (self + /nix/lib) final super) // inputs.home-manager.lib));

    mkSystem = hostname: {
      nixpkgs,
      modules,
    }: let
      lib = nixpkgs.lib.extend (final: super: ((import (self + /nix/lib) final super) // inputs.home-manager.lib));
    in
      lib.nixosSystem {
        modules =
          [
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote

            # Custom options.
            ./nix/nixos/modules

            # Make `nix run nixpkgs#nixpkgs` use the same
            # package repository as the one used here.
            # {
            #   nix.registry.nixpkgs.flake = lib.mkForce nixpkgs;
            # }

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

    mkHome = user: {
      nixpkgs,
      imports ? [],
    }: let
      lib = nixpkgs.lib.extend (final: super: ((import (self + /nix/lib) final super) // inputs.home-manager.lib));
    in [
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
            inherit imports;
          };
        };
      })
    ];
  in {
    # `nix develop`
    devShells = forSystems (system: let
      pkgs = mkPackages system inputs.nixpkgs-nixos-unstable-small;
    in {
      default = import ./nix/dev-shell/default.nix pkgs;
    });

    # `nix fmt`
    formatter = forSystems (
      system: (mkPackages system inputs.nixpkgs-nixos-unstable-small).alejandra
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
        nixpkgs = inputs.nixpkgs-nixos-unstable-small;
      in
        mkSystem "aether" {
          inherit nixpkgs;
          modules =
            [
              ./etc/aether
            ]
            ++ (mkHome "git" {
              inherit nixpkgs;
              imports = [
                ./dot/aether/git
              ];
            });
        };

      albedo = let
        nixpkgs = inputs.nixpkgs-nixos-unstable;
      in
        mkSystem "albedo" {
          inherit nixpkgs;
          modules =
            [
              ./etc/albedo
            ]
            ++ (mkHome "alex" {
              inherit nixpkgs;
              imports = [
                ./dot/albedo/alex
              ];
            });
        };
    };

    packages = forSystems (
      system: let
        pkgs = mkPackages system inputs.nixpkgs-nixos-unstable-small;
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
                nixpkgs = inputs.nixpkgs-nixos-unstable;
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
                    ++ (mkHome "yelan" {
                      inherit nixpkgs;
                      imports = [
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
