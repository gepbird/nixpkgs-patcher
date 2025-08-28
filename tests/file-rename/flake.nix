{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/44edb9645db4dd80fcdc0a060f28580d7b1f6bd2";
    nixpkgs-patcher.url = "path:../..";
    nixpkgs-patch-msmtp-build-fix-1-8-30 = {
      url = "https://github.com/NixOS/nixpkgs/pull/425312.diff";
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
            expr = unpatched.pkgs.msmtp.version;
            expected = "1.8.26";
          };
          testPatchedPackageVersion = {
            expr = patched.pkgs.msmtp.version;
            expected = "1.8.30";
          };
        };
    };
}
