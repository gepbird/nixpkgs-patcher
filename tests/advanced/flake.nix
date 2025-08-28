{
  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/3d79cbf3caec8f7482ad176f63701168b66e08a3";
    nixpkgs-patcher.url = "../..";
    osu-nix-pr-10-605-3 = {
      url = "https://github.com/NixOS/nixpkgs/compare/pull/414172/head~2...pull/414172/head.diff";
      flake = false;
    };
    osu-nix-pr-20-607-0 = {
      url = "path:./osu-nix-pr-20-607-0.diff";
      flake = false;
    };
  };

  outputs =
    inputs: with inputs; {
      nixosConfigurations.patched = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          (
            { ... }:
            {
              nixpkgs-patcher = {
                enable = true;
                settings.patches = [
                  ./nixos-lact-init.diff
                ];
              };

              services.glance = {
                enable = true;
                environmentFile = "/run/secrets/glance";
              };
            }
          )
        ];
        nixpkgsPatcher = {
          inherit inputs;
          nixpkgs = nixpkgs-unstable;
          patchInputRegex = ".*nix-pr.*";
          patches =
            pkgs: with pkgs; [
              (fetchpatch2 {
                name = "glance-environment-file.diff";
                url = "https://github.com/gepbird/nixpkgs/commit/3bddd16a376b1e7360395ccc4ca1d702644513ce.diff";
                hash = "sha256-QURZbwS/3P7iwSiVezPPFEzbRTbT/1fH7dHSdjEU+ok=";
              })
            ];
        };
      };

      nixosConfigurations.unpatched = nixpkgs-unstable.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      };

      checks.x86_64-linux.tests =
        let
          inherit (self.nixosConfigurations) patched unpatched;
        in
        (import ../lib.nix { nixpkgs = nixpkgs-unstable; }).runTests {
          testUnpatchedOsuVersion = {
            expr = unpatched.pkgs.osu-lazer-bin.version;
            expected = "2025.424.0";
          };
          testPatchedOsuVersion = {
            expr = patched.pkgs.osu-lazer-bin.version;
            expected = "2025.607.0";
          };
          testUnpatchedGlanceOptionDoesntExist = {
            expr = unpatched.config.services.glance ? environmentFile;
            expected = false;
          };
          testPatchedGlanceOptionIsSet = {
            expr = patched.config.services.glance.environmentFile;
            expected = "/run/secrets/glance";
          };
          testPatchedGlanceOptionHasEffect = {
            expr = patched.config.systemd.services.glance.serviceConfig.EnvironmentFile;
            expected = "/run/secrets/glance";
          };
          testUnpatchedLactModuleDoesntExist = {
            expr = unpatched.config.services ? lact;
            expected = false;
          };
          testPatchedLactModuleExist = {
            expr = patched.config.services ? lact;
            expected = true;
          };
        };
    };
}
