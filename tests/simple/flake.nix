{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dd90a8666b501e6068a1d56fe6f0b1da85ccac06";
    nixpkgs-patcher.url = "path:../..";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
      flake = false;
    };
  };

  outputs =
    inputs: with inputs; {
      nixosConfigurations.patched = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
        specialArgs = inputs;
      };

      nixosConfigurations.unpatched = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
        specialArgs = inputs;
      };

      checks.x86_64-linux.tests =
        let
          inherit (self.nixosConfigurations) patched unpatched;
        in
        (import ../lib.nix { inherit nixpkgs; }).runTests {
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
