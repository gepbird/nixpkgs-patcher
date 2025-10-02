{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/44edb9645db4dd80fcdc0a060f28580d7b1f6bd2";
    nixpkgs-patcher.url = "path:../..";
  };

  outputs =
    inputs: with inputs; {
      nixosConfigurations.unpatched = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
        specialArgs = inputs;
      };

      nixosConfigurations.patchedFails = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
        specialArgs = inputs;
        nixpkgsPatcher.patches = pkgs: [
          # this test is known to be failing
          # https://github.com/gepbird/nixpkgs-patcher/issues/3
          # https://github.com/twaugh/patchutils/issues/109
          (pkgs.fetchpatch2 {
            name = "msmtp-build-fix-1-8-30.diff";
            url = "https://github.com/NixOS/nixpkgs/pull/425312.diff";
            hash = "sha256-4YpIJ+ZrxEE/5jzKqOaaGWLoDlIG71xheXXu+mOG7vQ=";
          })
        ];
      };

      nixosConfigurations.patchedWorks = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
        specialArgs = inputs;
        nixpkgsPatcher.patches = pkgs: [
          (pkgs.fetchurl {
            name = "msmtp-build-fix-1-8-30.diff";
            url = "https://github.com/NixOS/nixpkgs/pull/425312.diff";
            hash = "sha256-Laf37gN6jmU2FCCKRHgsiwceMmM5aPSHVi56bPfVB8g=";
          })
        ];
      };

      checks.x86_64-linux.tests =
        let
          inherit (self.nixosConfigurations) unpatched patchedFails patchedWorks;
          lib = import ../lib.nix { inherit nixpkgs; };
        in
        lib.runTests {
          # this is failing, because msmtp doesn't build
          #testUnpatchedSystemBuilds = lib.testNixosConfigurationBuilds unpatched;
          # this is failing, because fetchpatch2 ignores renames, it should be asserted
          #testPatchedFailsSystemBuilds = lib.testNixosConfigurationBuilds patchedFails;
          testPatchedWorksSystemBuilds = lib.testNixosConfigurationBuilds patchedWorks;
          testUnpatchedPackageVersion = {
            expr = unpatched.pkgs.msmtp.version;
            expected = "1.8.26";
          };
          testPatchedFailsPackageVersion = {
            expr = patchedFails.pkgs.msmtp.version;
            expected = "1.8.30";
          };
          testPatchedWorksPackageVersion = {
            expr = patchedWorks.pkgs.msmtp.version;
            expected = "1.8.30";
          };
        };
    };
}
