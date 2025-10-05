### Using Different Base nixpkgs

By default, this flake assumes that you have an input called `nixpkgs`. It's possible that you have `nixpkgs-unstable` and `nixpkgs-stable` (or named them entirely differently). In that case, you can configure which should be used as a base.

```nix
# file: flake.nix
{
  outputs =
    { nixpkgs-patcher, nixpkgs-stable, nixpkgs-unstable, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        nixpkgsPatcher.nixpkgs = nixpkgs-unstable;
      };
    };
}
```

### Avoiding `specialArgs` Pollution

If you don't want to pass down every input to `specialArgs`, or if you have a different structure for it, you can provide your inputs in another way.

```nix
# file: flake.nix
{
  outputs =
    { nixpkgs-patcher, foo-flake, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        specialArgs = { inherit (inputs) foo-flake }; # keep your specialArgs however it was before
        nixpkgsPatcher.inputs = inputs;
      };
    };
}
```

### Naming Patches Differently

If you don't want to start every patch's name with `nixpkgs-patch-`, you can change the regex that is used to filter the inputs.

```nix
# file: flake.nix
{
  inputs = {
    # ...
    # all of these will be treated as patches because they contain "nix-pr"
    git-review-nix-pr = ...;
    nix-pr-mycelium = ...;
  };

  outputs =
    { nixpkgs-patcher, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        nixpkgsPatcher.patchInputRegex = ".*nix-pr.*"; # default: "^nixpkgs-patch-.*"
      };
    };
}
```

### Using a Different System for Evaluation

For example trying to query the hostname of an aarch64-linux host on an x86_64-linux machine would fail by default, but if you specify `nixpkgsPatcher.system` to be the current machine's system, it works:
```nix
# file: flake.nix
{
  outputs = 
  { nixpkgs-patcher, ... }@inputs:
  {
    nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
      # ...
      modules = [
        {
          nixpkgs.hostPlatform.system = "aarch64-linux";
          networking.hostName = "yourHostname";
        }
      ];
      nixpkgsPatcher.system = "x86_64-linux";
    }
  }
}

# run `nix eval .#nixosConfigurations.yourHostname.config.networking.hostName` to query the hostname
```

This can be useful when using [nixpkgs-patcher with NixOS-DNS](https://github.com/gepbird/nixpkgs-patcher/issues/4).

