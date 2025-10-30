{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dd90a8666b501e6068a1d56fe6f0b1da85ccac06";
    nixpkgs-patcher.url = "../..";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
      flake = false;
    };
  };

  outputs =
    inputs: with inputs; {
      nixosConfigurations.patched = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./base-configuration.nix
          (
            {
              pkgs,
              nixpkgs-patched,
              ...
            }:
            let
              pkgs-patched = import nixpkgs-patched {
                inherit (pkgs) system;
              };
            in
            {
              nixpkgs.overlays = [
                (final: prev: {
                  inherit (pkgs-patched) git-review;
                })
              ];
            }
          )
        ];
        specialArgs = inputs;
      };

      nixosConfigurations.unpatched = nixpkgs.lib.nixosSystem {
        modules = [
          ./base-configuration.nix
        ];
        specialArgs = inputs;
      };

      checks.x86_64-linux.tests =
        let
          inherit (self.nixosConfigurations) patched unpatched;
          lib = import ../lib.nix { inherit nixpkgs; };
        in
        lib.runTests {
          testUnpatchedSystemBuilds = lib.testNixosConfigurationBuilds unpatched;
          testPatchedSystemBuilds = lib.testNixosConfigurationBuilds patched;
          testUnpatchedPackageVersion = {
            expr = unpatched.pkgs.git-review.version;
            expected = "2.4.0";
          };
          testPatchedPackageVersion = {
            expr = patched.pkgs.git-review.version;
            expected = "2.5.0";
          };
        };
    };
}
