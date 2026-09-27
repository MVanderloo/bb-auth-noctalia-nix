{
  description = "Nix/Home Manager integration for bb-auth + Noctalia";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Used only by checks; the exported module uses the consumer's Home Manager.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays.default = final: _prev: {
        bb-auth = final.callPackage ./pkgs/bb-auth.nix { };
        noctalia-bb-auth-plugin = final.callPackage ./pkgs/noctalia-bb-auth-plugin.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs) bb-auth noctalia-bb-auth-plugin;
          default = pkgs.bb-auth;
        }
      );

      homeModules.default = import ./modules/home-manager.nix;

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) bb-auth noctalia-bb-auth-plugin;
        home-manager = import ./tests/home-manager.nix {
          inherit home-manager;
          pkgs = nixpkgs.legacyPackages.${system};
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
