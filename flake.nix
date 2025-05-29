{
  inputs = {
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    systems,
    nixpkgs,
    astal,
  }: let
    perSystem = attrs:
      nixpkgs.lib.genAttrs (import systems) (system:
        attrs (import nixpkgs {
          inherit system;
          overlays = [
            astal.overlays.default
            self.overlays.default
          ];
        }));
  in {
    # TODO: use overlays here
    lib.bundle = import ./nix/bundle.nix {
      inherit self;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };

    packages = perSystem (pkgs:
      pkgs.astal
      // {
        inherit (pkgs) ags agsFull;
        default = pkgs.ags;
      });

    overlays = {
      ags = final: prev: let
        inherit (final.astal) astal3 astal4 io gjs;

        astal-io = io;
        astal-gjs = "${gjs}/share/astal/gjs";
      in {
        ags = final.callPackage ./nix {
          inherit astal3 astal4 astal-io astal-gjs;
        };
        agsFull = final.callPackage ./nix {
          inherit astal3 astal4 astal-io astal-gjs;
          extraPackages = builtins.attrValues (
            builtins.removeAttrs final.astal [
              "docs"
              "buildAstalModule"
              "docs"
              "source"
            ]
          );
        };
      };
      default = self.overlays.ags;
    };

    templates.default = {
      path = ./nix/template;
      description = "Example flake.nix that shows how to package a project.";
      welcomeText = ''
        # Getting Started
        - run `nix develop` to enter the development environment
        - run `ags init -d . -f` to setup an initial ags project
        - run `ags run .`   to run the project
      '';
    };

    homeManagerModules = {
      default = self.homeManagerModules.ags;
      ags = import ./nix/hm-module.nix self;
    };

    devShells = perSystem (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          markdownlint-cli2
          marksman
          vtsls
          vscode-langservers-extracted
          go
          gopls
          gotools
          go-tools
        ];
      };
    });

    formatter = perSystem (pkgs: pkgs.alejandra);
  };
}
