{
  description = ''
    Reproducible configuration for Aether (Server), Albedo (Laptop), Lumine (Remote Server) and Beidou (Air-Gapped Bootable).
  '';

  inputs = {
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For server systems (hosts).
    # ────────────────────────────────────────────────────────────────────────
    nixpkgs-nixos-unstable-small = {
      url = "github:nixos/nixpkgs?rev=090e478bd64824e2122328df47a7efb74fdaf0c1"; # nixos-unstable-small
    };

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For desktop-oriented systems (workstations) and software
    #       with long build times (e.g. Firefox, Chromium, Electron).
    # ────────────────────────────────────────────────────────────────────────
    nixpkgs-nixos-unstable = {
      url = "github:nixos/nixpkgs?rev=34ab99075ac4f7e40cf037eef32cb1c360bb85e9"; # ~nixos-unstable
    };

    # ────────────────────────────────────────────────────────────────────────
    impermanence = {
      url = "github:nix-community/impermanence";
    };

    "dns.nix" = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs-nixos-unstable-small";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
    };
  };

  outputs = {self, ...} @ inputs: let
    inherit (lib.customisation) callPackageWith;
    inherit (lib.filesystem) packagesFromDirectoryRecursive;
    inherit (lib.attrsets) attrValues genAttrs;

    forSystems = genAttrs [
      "x86_64-linux"
    ];

    mkLib = nixpkgs:
      nixpkgs.lib.extend (final: super: let
        custom = import (self + "/nix/lib") final super;
        hm = inputs.home-manager.lib;
      in
        hm
        // custom
        // {
          types = custom.types;
        })
      // {
        dns =
          inputs."dns.nix".lib;
      };

    lib = mkLib inputs.nixpkgs-nixos-unstable-small;

    mkPackages = system: pkgs:
      import pkgs {
        inherit system;

        overlays = attrValues self.overlays;
      };

    mkSystem = hostname: {
      nixpkgs,
      modules,
    }: let
      lib = mkLib nixpkgs;
    in
      lib.nixosSystem {
        modules =
          [
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote

            # Custom options.
            ./nix/nixos

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
              system.stateVersion = "26.05";
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
      lib = mkLib nixpkgs;
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
        lib = _: _: {
          inherit lib;
        };

        packages = final: _: {
          inherit (self.packages.${final.stdenv.hostPlatform.system}) certs davis notes;
        };

        aliases = import (./nix + "/fixes?/aliases.nix");

        tools = final: _: {
          custom.writeAuthZone = import ./nix/packages/tools/write-auth-zone/package.nix final;
          custom.writeShell = import ./nix/packages/tools/write-shell/package.nix final;
          custom.scripts = scripts ./nix/packages/scripts final;
        };

        dns = final: _: {
          dns.util = inputs."dns.nix".util.${final.stdenv.hostPlatform.system};
        };

        formats = final: super: {
          formats =
            super.formats
            // {
              plist = import ./nix/packages/formats/plist.nix final;
              kdl = import ./nix/packages/formats/kdl.nix final;
              strongswan = import ./nix/packages/formats/strongswan.nix final;
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
          modules = [
            ./etc/aether
          ];
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
                ./dot/albedo/by-user/alex
              ];
            });
        };

      lumine = let
        nixpkgs = inputs.nixpkgs-nixos-unstable;
      in
        mkSystem "lumine" {
          inherit nixpkgs;
          modules = [
            ./etc/lumine
          ];
        };
    };

    packages = forSystems (
      system: let
        pkgs = mkPackages system inputs.nixpkgs-nixos-unstable-small;
      in
        packagesFromDirectoryRecursive {
          callPackage = callPackageWith (pkgs // {inherit lib;});
          directory = ./nix/packages/by-name;
        }
    );
  };
}
