{
  description = ''
    Reproducible configuration for Albedo (Laptop), Beidou (Server), and Collei (VPS).
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
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    "dns.nix" = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixos-unstable";
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

    lib = mkLib inputs.nixos-unstable-small;

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
    in let
      inherit (lib.extra.files.list) recursive;
    in
      lib.nixosSystem {
        modules =
          [
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote

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
              nixpkgs = {
                config = {
                  allowUnfreePredicate = pkg:
                    builtins.elem (lib.getName pkg) (
                      builtins.concatLists [
                        # DIVERSE
                        # -------
                        [
                          "fcitx5-black-simplicity"
                          "n8n"
                          "n8n-task-runner-launcher"
                          "obsidian"
                        ]
                        # NVIDIA
                        # ------
                        [
                          "nvidia-kernel-modules"
                          "nvidia-settings"
                          "nvidia-x11"
                        ]
                        # CUDA
                        # ----
                        [
                          "cuda_cccl"
                          "cuda_cudart"
                          "cuda_nvcc"
                          "cuda_nvrtc"
                          "libcublas"
                        ]
                      ]
                    );
                };
              };
            }

            {
              system.stateVersion = "26.05";
            }
          ]
          ++ (recursive ./nix/modules/nixos) ++ modules;
        specialArgs = {
          inherit lib self inputs;
        };
      };

    mkHome = user: {
      nixpkgs,
      imports ? [],
    }: let
      lib = mkLib nixpkgs;
    in let
      inherit (lib.extra.files.list) recursive;
    in [
      inputs.home-manager.nixosModules.home-manager
      (_: {
        home-manager = {
          # Custom options.
          sharedModules = recursive ./nix/modules/home-manager;

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
      pkgs = mkPackages system inputs.nixos-unstable-small;
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          shellcheck
          alejandra

          deadnix
          vulnix

          nixd
          shfmt
          statix

          opentofu
        ];
      };
    });

    # `nix fmt`
    formatter = forSystems (
      system: (mkPackages system inputs.nixos-unstable-small).alejandra
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
          nixpkgs = inputs.nixos-unstable-small;
        in {
          beidou = mkSystem "beidou" {
            inherit nixpkgs;
            modules = singleton ./etc/beidou;
          };

          collei = mkSystem "collei" {
            inherit nixpkgs;
            modules = singleton ./etc/collei;
          };

          fischl = mkSystem "fischl" {
            inherit nixpkgs;
            modules = singleton ./etc/fischl;
          };
        })
        # Workstations
        # ------------
        (let
          nixpkgs = inputs.nixos-unstable;
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
        pkgs = mkPackages system inputs.nixos-unstable-small;
      in
        packagesFromDirectoryRecursive {
          callPackage = callPackageWith (pkgs // {inherit lib;});
          directory = ./nix/packages/by-name;
        }
    );
  };
}
