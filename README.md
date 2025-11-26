
# nixpkgs-patcher

Using [nixpkgs](https://github.com/NixOS/nixpkgs) pull requests that haven't landed into your channel has never been easier!

You can use it for your [NixOS configuration](#install-nixpkgs-patcher-for-nixos) or with [other flake outputs](#using-patched-nixpkgs-in-other-flake-outputs) like `packages` or `devShells`.

## Getting Started

### Install nixpkgs-patcher for NixOS

Modify your flake accordingly:
- Use `nixpkgs-patcher.lib.nixosSystem` instead of `nixpkgs.lib.nixosSystem`
- Ensure that you pass the `inputs` to `specialArgs`

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
  };

  outputs =
    { nixpkgs-patcher, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
        ];
        specialArgs = inputs;
      };
    };
}
```

### Add a PR

Create a new input that starts with `nixpkgs-patch-`, which points to the diff of your PR and indicates that it's not a flake. In this example, we perform a package bump for `git-review`. The PR number is `410328`, and we take the diff between the master branch and it.

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
      flake = false;
    };
  };
}
```

Rebuild your system and enjoy using the PRs early!

## Configuration

The above introduction is likely everything you need to know to use this flake effectively. However, there are additional configuration options for more advanced use cases.

See the [configuration documentation](doc/configuration.md).

## Adding Patches

### Using Flake Inputs

This is the fastest way in my opinion, because all you have to do is add a flake input. Updating flake inputs will also update your patches. Here are some examples:

```nix
# file: flake.nix
{
  inputs = {
    # include a package bump from a nixpkgs PR
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
      flake = false;
    };
  };
}
```

### Using nixpkgsPatcher Config

You can also define patches similarly to how you configured this flake. Provide a `nixpkgsPatcher.patches` attribute to `nixosSystem` that takes in `pkgs` and outputs a list of patches.

```nix
# file: flake.nix
{
  outputs =
    { nixpkgs-patcher, ... }@inputs:
    {
      nixosConfigurations.yourHostname = nixpkgs-patcher.lib.nixosSystem {
        # ...
        nixpkgsPatcher.patches =
          pkgs: with pkgs; [
            (fetchurl {
              name = "git-review-bump.patch";
              url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
              hash = ""; # rebuild, wait for nix to fail and give you the hash, then put it here
            })
            (fetchurl {
              # ...
            })
          ];
      };
    };
}
```

### Using Your Configuration

After installing nixpkgs-patcher, you can apply patches from your config without touching flake.nix.

```nix
# file: configuration.nix
{ pkgs, ... }: 

{
  environment.systemPackages = with pkgs; [
    # ...
  ];

  nixpkgs-patcher = {
    enable = true;
    settings.patches = with pkgs; [
      (fetchurl {
        name = "git-review-bump.patch";
        url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
        hash = ""; # rebuild, wait for nix to fail and give you the hash, then put it here
      })
    ];
  };
}
```

### Example patch formats

```nix
# file: flake.nix
{
  inputs = {
    # include a package bump from a nixpkgs PR
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
      flake = false;
    };

    # include a new module from a nixpkgs PR
    nixpkgs-patch-lasuite-docs-module-init = {
      url = "https://github.com/NixOS/nixpkgs/pull/401798.diff";
      flake = false;
    };

    # include a patch from your (or someone else's) fork of nixpkgs by a branch name
    nixpkgs-patch-lasuite-docs-module-init = {
      url = "https://github.com/NixOS/nixpkgs/compare/master...gepbird:nixpkgs:xppen-init-v3-v4-nixos-module.diff";
      flake = false;
    };

    # local patch (don't forget to git add the file!)
    nixpkgs-patch-git-review-bump = {
      url = "path:./patches/git-review-bump.patch";
      flake = false;
    };

    # patches are ordered and applied alphabetically; if one patch depends on another, you can prefix them with a number to make the ordering clear
    nixpkgs-patch-10-mycelium-0-6-0 = {
      url = "https://github.com/NixOS/nixpkgs/pull/402466.diff";
      flake = false;
    };
    nixpkgs-patch-20-mycelium-0-6-1 = {
      url = "https://github.com/NixOS/nixpkgs/pull/410367.diff";
      flake = false;
    };

    # compare against master, nixos-unstable or a stable branch like nixos-25.05
    nixpkgs-patch-lasuite-docs-module-init = {
      url = "https://github.com/NixOS/nixpkgs/compare/nixos-unstable...pull/401798/head.diff";
      flake = false;
    };

    # don't compare against master, but take the last x (in this case 5) commits of the PR
    nixpkgs-patch-lasuite-docs-module-init = {
      url = "https://github.com/NixOS/nixpkgs/compare/pull/401798/head~5...pull/401798/head.diff";
      flake = false;
    };

    # only a single commit, you'll get the same patches every time
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/commit/1123658f39e7635e8d10a1b0691d2ad310ac24fc.diff";
      flake = false;
    };

    # a range of commits, you'll get the same patches every time
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/compare/b024ced1aac25639f8ca8fdfc2f8c4fbd66c48ef...0330cef96364bfd90694ea782d54e64717aced63.diff";
      flake = false;
    };
  };
}
```

You can use these patch formats with all the 3 methods above, not only as flake inputs.

PRs can change over time, some commits might be added or replaced by a force-push.
To update only a single patch you can run `nix flake update nixpkgs-patch-git-review-bump` for example.
Running your usual flake update command like `nix flake update --commit-lock-file` will also update all patches.
If you use an "unstable" URL format like `https://github.com/NixOS/nixpkgs/pull/410328.diff`, you can get different patches at different time, or even different patches at the sime time on different machines because Nix already downloaded and cached the patch on one machine but not on the other.
To guarantee reproducibility, you can use the `https://github.com/NixOS/nixpkgs/commit/1123658f39e7635e8d10a1b0691d2ad310ac24fc.diff` format for single commits, or `https://github.com/NixOS/nixpkgs/compare/b024ced1aac25639f8ca8fdfc2f8c4fbd66c48ef...0330cef96364bfd90694ea782d54e64717aced63.diff` for a range of commits.
To be extra sure you can use download the patch and reference to it by a local path, or use a different method that requires specifying a hash (see below).

> [!NOTE]  
> Using URLs like `https://github.com/NixOS/nixpkgs/pull/410328.diff` is shorter and more convenient, but a few months ago this was heavily rate limited. If you run into such errors, you can use other formats mentioned above. 

> [!NOTE]  
> If you are using `fetchpatch`, `fetchpatch2` (or anything that uses `filterdiff` under the hood) instead of `fetchurl`, patching can fail if the only change to any files in the patch is a rename.

## Using Patched Nixpkgs in Other Flake Outputs

### Basic Usage

This flake provides a standalone `patchNixpkgs` function that in essence takes in the base nixpkgs and outputs a patched version of it.
Usually you also need to provide the `system` and your `inputs` which contain the patches and your base nixpkgs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
    nixpkgs-patch-git-review-bump = {
      url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
      flake = false;
    };
  };

  outputs =
    { nixpkgs-patcher, ... }@inputs:
    {
      packages.x86_64-linux.patched-git-review =
        let
          system = "x86_64-linux";
          nixpkgs-patched = nixpkgs-patcher.lib.patchNixpkgs { inherit inputs system; };
          pkgs-patched = import nixpkgs-patched { inherit system; };
        in
        pkgs-patched.git-review
    };
}
```

### Advanced Usage

Options mentioned in the [configuration documentation](doc/configuration.md) like naming patch inputs differently, using a different base nixpkgs, or [using patches with `fetchurl`](#using-nixpkgspatcher-config) instead of flake inputs can be similarly achieved with this function, here's a comprehensive example:

```nix
{
  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
    nix-pr-mycelium = {
      url = "https://github.com/NixOS/nixpkgs/pull/410367.diff";
      flake = false;
    };
  };

  outputs =
    { nixpkgs-patcher, nixpkgs, ... }@inputs:
    {
      devShells.x86_64-linux.patched-git-review =
        let
          system = "x86_64-linux";
          pkgs = import nixpkgs { inherit system; };
          nixpkgs-patched = nixpkgs-patcher.lib.patchNixpkgs {
            inherit system;
            nixpkgs = nixpkgs-unstable;
            patchInputRegex = ".*nix-pr.*"; # default: "^nixpkgs-patch-.*"
            patches = pkgs: [
              (pkgs.fetchurl {
                name = "git-review-bump.diff";
                url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/410328.diff?full_index=1";
                hash = "sha256-ucUzVEUNfVI+WxDGhzcYywhHOaPrwZRg/9iqkNQGYYw=";
              })
            ]
            # if you provide your `nixpkgs` and `patches` and don't plan to use flake input patches, you can remove `inputs`
            inputs
            # optional, if you already have a reference to `pkgs`, this can improve evaluation performance slightly and you don't need to pass `system` in this case
            pkgs
          };
          pkgs-patched = import nixpkgs-patched {
            system = "x86_64-linux";
          };
        in
        pkgs-patched.mkShell {
          packages = with pkgs-patched; [
            git-review
            mycelium
          ];
        };
    };
}
```

> [!NOTE]
> Unfortunately the patched nixpkgs is only useful for `import`-ing, it doesn't provide flake attributes like `legacyPackages` or `lib`. For `lib.nixosSystem` you can use [`nixpkgs-patcher.lib.nixosSystem`](#install-nixpkgs-patcher-for-nixos). If you need other attributes, please open an issue.


## Troubleshooting

See the [troubleshooting documentation](doc/troubleshooting.md).

## Comparison with Alternatives

This flake focuses on ease of use for patching nixpkgs and using it with NixOS.
It requires less effort to understand and quickly start using it compared to alternatives.
However, if you want to patch other flake inputs or use patches inside packages or devshells, check out the alternatives!

| | nixpkgs-patcher | [nix-patcher](https://github.com/katrinafyi/nix-patcher) | [flake-input-patcher](https://github.com/jfly/flake-input-patcher) |
|------------------------------                                               |----|----|----|
| Patches defined as [flake inputs](#using-flake-inputs)                      | ✅ | ✅ | ❌ |
| Patches defined in [your NixOS configuration](#using-your-configuration)    | ✅ | ❌ | ❌ |
| Patches using [fetchurl](#using-your-configuration)                         | ✅ | ❌ | ✅ |
| Local only                                                                  | ✅ | ❌ | ✅ |
| No extra eval time spent with locally applying patches (cached)             | ❌ | ✅ | ❌ |
| Doesn't require additional tools                                            | ✅ | ❌ | ✅ |
| Automatic `system` detection                                                | ✅ | ✅ | ❌ |
| Works for any flake on GitHub                                               | ❌ | ✅ | ✅ |
| Works for any flake                                                         | ❌ | ❌ | ✅ |
| [IFD](https://nix.dev/manual/nix/2.29/language/import-from-derivation) free | ❌ | ✅ | ❌ |
| Can be used for modifying other flake inputs' `nixpkgs`                     | ❌ | ✅ | ❌ |

### Why Not Just Use Overlays?

For individual packages, using overlays can appear straightforward:

1. Add the forked nixpkgs by a branch reference:

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-git-review-bump.url = "github:kira-bruneau/nixpkgs/git-review";
  };
}
```

2. Apply it with an overlay:

```nix
# file: configuration.nix
{ pkgs, nixpkgs-git-review-bump, ... }: 

let
  pkgs-git-review = import nixpkgs-git-review-bump { inherit (pkgs) system; };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      git-review = pkgs-git-review.git-review;
    })
  ];
}
```

Package sets such as KDE (and previously GNOME) have their own way of [overriding packages](https://wiki.nixos.org/wiki/KDE#Customizing_nixpkgs).

Overriding modules becomes finicky when you want to try out a module update PR. You must disable the old module first, add the module from the PR, and reference relative file paths, all while hoping that it works in the end. And add dependant packages with overlays.

```nix
# file: configuration.nix
{ pkgs, nixpkgs-pocket-id, ... }:

{
  disabledModules = [
    "services/security/pocket-id.nix"
  ];
  imports = [
    "${nixpkgs-pocket-id}/nixos/modules/services/security/pocket-id.nix"
  ];

  nixpkgs.overlays =
    let
      pkgs-pocket-id = import nixpkgs-pocket-id { inherit (pkgs) system; };
    in
    [
      (final: prev: {
        pocket-id = pkgs-pocket-id.pocket-id;
      })
    ];
}
```

## Contributing

Bug reports, feature requests, and PRs are welcome!

## Credits

- people involved in [the issue about patching flake inputs](https://github.com/NixOS/nix/issues/3920)
- [patch-nixpkgs article](https://ertt.ca/nix/patch-nixpkgs/)
- [flake-input-patcher](https://github.com/jfly/flake-input-patcher)
- [nix-patcher](https://github.com/katrinafyi/nix-patcher)
