{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/44edb9645db4dd80fcdc0a060f28580d7b1f6bd2";
    nixpkgs-patcher.url = "path:../..";
  };

  outputs =
    inputs: with inputs; {
      nixosConfigurations.patched = nixpkgs-patcher.lib.nixosSystem {
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
          lib = import ../lib.nix { inherit nixpkgs; };
        in
        lib.runTests {
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
