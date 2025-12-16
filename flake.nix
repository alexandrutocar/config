# https://nix.dev/manual/nix/2.24/command-ref/new-cli/nix3-flake.html#flake-format
{
  description = "Configuration Files";

  inputs = {
    unstable.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    stable.url = "github:nixos/nixpkgs/?ref=nixos-25.11";

    nixos-facter-modules = {
      url = "github:nix-community/nixos-facter-modules";
    };

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

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (lib.attrsets) attrValues genAttrs;
    inherit (lib.strings) getName;

    forSystems = genAttrs [
      "x86_64-linux"
    ];

    mkPackages = system: pkgs:
      import pkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (getName pkg) [
            "fcitx5-black-simplicity"
          ];
        overlays = attrValues self.overlays;
      };

    lib = inputs.nixpkgs.lib.extend (final: super: ((import (self + /nix/lib) final super) // inputs.home-manager.lib));

    mkSystem = {
      hostname,
      nixpkgs,
      modules,
    }:
      lib.nixosSystem {
        modules =
          [
            inputs.nixos-facter-modules.nixosModules.facter
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote

            # Custom options.
            ./nix/nixos/modules

            # Make `nix run nixpkgs#nixpkgs` use the same
            # package repository as the one used here.
            {
              nix.registry.nixpkgs.flake = nixpkgs;
            }

            # Ensure relevant system parts have
            # the specified name.
            {
              networking.hostName = hostname;
              nixpkgs.config.allowUnfree = true;
              hardware.bluetooth.settings.General.Name = hostname;
            }

            # Cross-system package overlays and prefixes of allowed unfree packages.
            {
              nixpkgs.overlays = builtins.attrValues self.overlays;
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
    # `nix develop --no-pure-eval` (https://devenv.sh)
    devShells = forSystems (system: let
      pkgs = mkPackages system inputs.unstable;
    in {
      default = inputs.devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [./tools.nix];
      };
    });

    # `nix fmt` (https://kamadorueda.com/alejandra)
    formatter = forSystems (
      system: (mkPackages system inputs.unstable).alejandra
    );

    overlays = let
      inherit (lib.custom.files.special) patches scripts;
    in
      {
        aliases = import (./nix + "/fixes?/aliases.nix");

        custom = final: super: {
          # PACKAGE ADDITIONS
          # -----------------
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
      aether = mkSystem {
        inherit (inputs) nixpkgs;
        hostname = "aether";
        modules =
          [
            ./etc/aether
          ]
          ++ (map mkHome [
            {
              user = "git";
              spec = [
                ./dot/aether
              ];
            }
          ]);
      };

      albedo = mkSystem {
        inherit (inputs) nixpkgs;
        hostname = "albedo";
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
    packages = forSystems (system: let
      pkgs = mkPackages system inputs.unstable;
    in {
      davis = pkgs.callPackage ./nix/packages/by-name/davis/package.nix {};
      depp = pkgs.callPackage ./nix/packages/by-name/depp/package.nix {};
      fcitx5-black-simplicity = pkgs.callPackage ./nix/packages/by-name/fcitx5-black-simplicity/package.nix {};
      foxessprom = pkgs.callPackage ./nix/packages/by-name/foxessprom/package.nix {};
      sonicradio = pkgs.callPackage ./nix/packages/by-name/sonicradio/package.nix {};
      tlm = pkgs.callPackage ./nix/packages/by-name/tlm/package.nix {};
    });
  };
}
