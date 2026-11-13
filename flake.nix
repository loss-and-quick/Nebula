{
  description = "Nebula — Material You desktop shell for Hyprland (Quickshell)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, quickshell }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      overlay = final: prev: {
        nebula = final.callPackage ./nix/package.nix {
          src = self;
          quickshell = quickshell.packages.${final.stdenv.hostPlatform.system}.default.withModules (with final.kdePackages; [ qqc2-desktop-style kirigami ]);
        };
      };
      homeModule = import ./nix/home-manager.nix self;
    in
    {
      overlays.default = overlay;
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
        in { default = pkgs.nebula; inherit (pkgs) nebula; });
      homeManagerModules = { default = homeModule; nebula = homeModule; };
      homeModules = self.homeManagerModules;
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cmake ninja qt6.qtbase qt6.qtdeclarative qt6.qtshadertools
              (python3.withPackages (ps: with ps; [ materialyoucolor pillow fonttools skia-pathops ]))
            ];
          };
        });
    };
}
