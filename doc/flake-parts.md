## Using `nixpkgs-patcher` with `flake-parts`

This example shows how to use `nixpkgs-patcher` in a **flake-parts** project to apply patches and use the patched `pkgs` in your NixOS configuration.

The process has three steps:

1. Add nixpkgs-patcher and patches as flake inputs
2. Patch nixpkgs in perSystem
3. Use the patched pkgs in your NixOS configuration

---

### 1. Add `nixpkgs-patcher` and patches as flake inputs

Add `nixpkgs-patcher` and any patches (such as nixpkgs PRs) to your `flake.nix` inputs.

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";

    # Example nixpkgs PR patch
    nixpkgs-patch-update-osu-lazer = {
      url = "https://github.com/NixOS/nixpkgs/pull/496840.diff";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        ./hosts/hostname.nix # <- host configuration
        ./nixpkgs.nix # <- nixpkgs configuration module
        # ...
      ];
    };
}
```

### 2. Patch nixpkgs in `perSystem`

Create a module that generates a **patched nixpkgs** using `patchNixpkgs`.
Then expose it as the `pkgs` argument used by the rest of the flake.

```nix
# file: nixpkgs.nix
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
```

### 3. Use the patched `pkgs` in a NixOS configuration

When defining a host, use [`withSystem`](https://flake.parts/module-arguments.html?highlight=withSystem#withsystem) to access the system scope.
Instead of using `nixpkgs.lib.nixosSystem`, use: `nixpkgs-patcher.lib.nixosSystem`.

```nix
# file: hosts/hostname.nix
{ inputs, withSystem, ... }:
{
  flake.nixosConfigurations.hostname = withSystem "x86_64-linux" (
    { pkgs, system, ... }:
    inputs.nixpkgs-patcher.lib.nixosSystem {
      inherit system;
      modules = [
        { nixpkgs.pkgs = pkgs; }
        # ...
      ];
    }
  );
}
```

---

### Result

Your NixOS system now uses **patched nixpkgs** with any patches you defined in the flake inputs.
