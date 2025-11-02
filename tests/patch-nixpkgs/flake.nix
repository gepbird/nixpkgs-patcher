{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dd90a8666b501e6068a1d56fe6f0b1da85ccac06";
    nixpkgs-2.url = "github:NixOS/nixpkgs/dd90a8666b501e6068a1d56fe6f0b1da85ccac06";
    nixpkgs-patcher.url = "../..";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
      flake = false;
    };
  };

  outputs =
    inputs:
    with inputs;
    let
      system = "x86_64-linux";
    in
    {
      packages.x86_64-linux =
        let
          pkgs-unpatched = import nixpkgs {
            inherit system;
          };
        in
        {
          unpatched = pkgs-unpatched.git-review;

          patchedSimple =
            let
              nixpkgs-patched = nixpkgs-patcher.lib.patchNixpkgs {
                inherit inputs system;
              };
              pkgs-patched = import nixpkgs-patched {
                inherit system;
              };
            in
            pkgs-patched.git-review;

          patchedAdvanced1 =
            let
              nixpkgs-patched = nixpkgs-patcher.lib.patchNixpkgs {
                inherit
                  system
                  nixpkgs
                  ;
                patches = pkgs: [
                  (pkgs.fetchurl {
                    name = "git-review-bump.diff";
                    url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/410328.diff?full_index=1";
                    hash = "sha256-ucUzVEUNfVI+WxDGhzcYywhHOaPrwZRg/9iqkNQGYYw=";
                  })
                ];
              };
              pkgs-patched = import nixpkgs-patched {
                inherit system;
              };
            in
            pkgs-patched.git-review;

          patchedAdvanced2 =
            let
              nixpkgs-patched = nixpkgs-patcher.lib.patchNixpkgs {
                inherit system;
                nixpkgs = nixpkgs-2;
                pkgs = pkgs-unpatched;
                patches = [
                  (pkgs-unpatched.fetchurl {
                    name = "git-review-bump.diff";
                    url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/410328.diff?full_index=1";
                    hash = "sha256-ucUzVEUNfVI+WxDGhzcYywhHOaPrwZRg/9iqkNQGYYw=";
                  })
                ];
              };
              pkgs-patched = import nixpkgs-patched {
                inherit system;
              };
            in
            pkgs-patched.git-review;
        };

      checks.x86_64-linux.tests =
        let
          inherit (self.packages.x86_64-linux)
            unpatched
            patchedSimple
            patchedAdvanced1
            patchedAdvanced2
            ;
          lib = import ../lib.nix { inherit nixpkgs; };
        in
        lib.runTests {
          testUnpatchedPackageVersion = {
            expr = unpatched.version;
            expected = "2.4.0";
          };
          testPatchedSimplePackageVersion = {
            expr = patchedSimple.version;
            expected = "2.5.0";
          };
          testPatchAdvanced1 = {
            expr = patchedAdvanced1.version;
            expected = "2.5.0";
          };
          testPatchAdvanced2 = {
            expr = patchedAdvanced2.version;
            expected = "2.5.0";
          };
        };
    };
}
