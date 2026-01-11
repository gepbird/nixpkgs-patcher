{
  description = "HyprNixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
    nixpkgs-patch-cursor-update = {
      url = "https://github.com/NixOS/nixpkgs/pull/479033.diff";
      flake = false;
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./flake-parts.nix ];
      systems = nixpkgs.lib.systems.flakeExposed;
    };
}
