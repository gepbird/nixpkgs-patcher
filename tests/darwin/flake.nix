{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dd90a8666b501e6068a1d56fe6f0b1da85ccac06";
    nixpkgs-patcher.url = "../..";
    nix-darwin.url = "github:nix-darwin/nix-darwin/19346808c445f23b08652971be198b9df6c33edc";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff?full_index=1";
      flake = false;
    };
  };

  outputs =
    inputs: with inputs; {
      darwinConfigurations.patched = nixpkgs-patcher.lib.darwinSystem {
        modules = [
          ./configuration.nix
        ];
        specialArgs = inputs;
      };

      darwinConfigurations.unpatched = nix-darwin.lib.darwinSystem {
        modules = [
          ./configuration.nix
        ];
        specialArgs = inputs;
      };

      checks.aarch64-darwin.tests =
        let
          inherit (self.darwinConfigurations) patched unpatched;
          lib = import ../lib.nix { inherit nixpkgs; system = "aarch64-darwin"; };
        in
        lib.runTests {
          testUnpatchedPackageVersion = {
            expr = unpatched.pkgs.git-review.version;
            expected = "2.4.0";
          };
          testPatchedPackageVersion = {
            expr = patched.pkgs.git-review.version;
            expected = "2.5.0";
          };

          testUnpatchedDarwinVersionSuffix = {
            expr = builtins.match "^\\.[0-9]+$" unpatched.config.system.darwinVersionSuffix != null;
            expected = true;
          };
          # note: this changes the original nix-darwin versionSuffix format as it has 2 numbers
          testPatchedDarwinVersionSuffix = {
            expr = builtins.match "^\\.[0-9]+\\.[0-9a-f]+-patched$" patched.config.system.darwinVersionSuffix != null;
            expected = true;
          };
        };
    };
}
