{ withSystem, inputs, ... }:
{
  flake = {
    nixosConfigurations.patched = withSystem "x86_64-linux" (
      { pkgs, system, ... }:
      inputs.nixpkgs-patcher.lib.nixosSystem {
        inherit system;
        specialArgs = inputs; # explicitly provide flake inputs
        modules = [
          { nixpkgs.pkgs = pkgs; } # apply patched pkgs
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      }
    );

    nixosConfigurations.unpatched = withSystem "x86_64-linux" (
      { system, ... }:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      }
    );
  };
}
