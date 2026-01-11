{ inputs, ... }:
let
  hostPlatform = "x86_64-linux";
in
{
  flake.nixosConfigurations.hyprnix = inputs.nixpkgs-patcher.lib.nixosSystem {
    specialArgs = { inherit inputs hostPlatform; };
    nixpkgsPatcher.nixpkgs = inputs.nixpkgs;
    modules = inputs.self.moduleTree {
    };
  };
}
