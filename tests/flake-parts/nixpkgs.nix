{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      nixpkgs-patched = inputs.nixpkgs-patcher.lib.patchNixpkgs {
        inherit system inputs;
        inherit (inputs) nixpkgs;
      };
    in
    {
      _module.args.pkgs = import nixpkgs-patched {
        inherit system;
      };
    };
}
