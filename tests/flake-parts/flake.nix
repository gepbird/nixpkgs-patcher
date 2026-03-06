{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dd90a8666b501e6068a1d56fe6f0b1da85ccac06";
    flake-parts.url = "github:hercules-ci/flake-parts/864599284fc7c0ba6357ed89ed5e2cd5040f0c04";
    nixpkgs-patcher.url = "../..";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff?full_index=1";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        ./nixpkgs.nix
        ./hosts.nix
      ];

      perSystem = {
        checks.tests =
          let
            inherit (inputs.self.nixosConfigurations) patched unpatched;
            lib = import ../lib.nix { inherit (inputs) nixpkgs; };
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
    };
}
