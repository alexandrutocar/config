{
  description = ''
    Reproducible configuration for Aether (Server), Albedo (Laptop) and Lumine (VPS).
  '';

  inputs = {
    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For server systems (hosts).
    # ────────────────────────────────────────────────────────────────────────
    smallest = {
      url = "github:nixos/nixpkgs?rev=090e478bd64824e2122328df47a7efb74fdaf0c1"; # nixos-unstable-small
    };

    # ────────────────────────────────────────────────────────────────────────
    # NOTE: For desktop-oriented systems (workstations) and software
    #       with long build times (e.g. Firefox, Chromium, Electron).
    # ────────────────────────────────────────────────────────────────────────
    unstable = {
      url = "github:nixos/nixpkgs?rev=34ab99075ac4f7e40cf037eef32cb1c360bb85e9"; # nixos-unstable
    };

    # ────────────────────────────────────────────────────────────────────────
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "unstable";
    };

    "dns.nix" = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "unstable";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "unstable";
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

    lib = mkLib inputs.smallest;

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
      pkgs = mkPackages system inputs.smallest;
    in {
      default = import ./nix/dev-shell/default.nix pkgs;
    });

    # `nix fmt`
    formatter = forSystems (
      system: (mkPackages system inputs.smallest).alejandra
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

    nixosConfigurations = let
      inherit (lib.attrsets) mergeAttrsList;
      inherit (lib.lists) singleton;
    in
      mergeAttrsList [
        # Hosts/Servers
        # -------------
        (let
          nixpkgs = inputs.smallest;
        in {
          aether = mkSystem "aether" {
            inherit nixpkgs;
            modules = singleton ./etc/aether;
          };

          lumine = mkSystem "lumine" {
            inherit nixpkgs;
            modules = singleton ./etc/lumine;
          };
        })
        # Workstations
        # ------------
        (let
          nixpkgs = inputs.unstable;
        in {
          albedo = mkSystem "albedo" {
            inherit nixpkgs;
            modules =
              (singleton ./etc/albedo)
              ++ (mkHome "alex" {
                inherit nixpkgs;
                imports = singleton ./dot/albedo/by-user/alex;
              });
          };
        })
      ];

    packages = forSystems (
      system: let
        pkgs = mkPackages system inputs.smallest;
      in
        packagesFromDirectoryRecursive {
          callPackage = callPackageWith (pkgs // {inherit lib;});
          directory = ./nix/packages/by-name;
        }
    );
  };
}
