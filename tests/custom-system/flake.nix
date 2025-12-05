{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/dd90a8666b501e6068a1d56fe6f0b1da85ccac06";
    nixpkgs-patcher.url = "../..";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff?full_index=1";
      flake = false;
    };
  };

  outputs =
    inputs: with inputs; {
      nixosConfigurations.unpatched = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          {
            nixpkgs.hostPlatform = "aarch64-linux";
            networking.hostName = "yourHostname";
          }
        ];
        specialArgs = inputs;
      };

      nixosConfigurations.patchedEvalFails = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          {
            nixpkgs.hostPlatform = "aarch64-linux";
            networking.hostName = "yourHostname";
          }
        ];
        specialArgs = inputs;
      };

      nixosConfigurations.patchedEvalWorks = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          {
            nixpkgs.hostPlatform = "aarch64-linux";
            networking.hostName = "yourHostname";
          }
        ];
        specialArgs = inputs;
        nixpkgsPatcher.system = "x86_64-linux";
      };

      checks.x86_64-linux.tests =
        let
          inherit (self.nixosConfigurations) unpatched patchedEvalFails patchedEvalWorks;
        in
        (import ../lib.nix { inherit nixpkgs; }).runTests {
          testUnpatchedHostname = {
            expr = unpatched.config.networking.hostName;
            expected = "yourHostname";
          };
          # TODO: assert that this fails
          #testPatchedEvalFails = {
          #  expr = builtins.tryEval patchedEvalFails.config.networking.hostName;
          #  expected = "eval failure";
          #};
          testPatchedEvalWorks = {
            expr = patchedEvalWorks.config.networking.hostName;
            expected = "yourHostname";
          };
        };
    };
}

