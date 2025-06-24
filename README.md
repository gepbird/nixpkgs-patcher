
# nixpkgs-patcher

Using [nixpkgs](https://github.com/NixOS/nixpkgs) pull requests that haven't landed into your channel has never been easier!

## Getting Started

### Install nixpkgs-patcher

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

Rebuild your system and enjoy using the PRs early! This is likely everything you need to know to use this flake effectively. However, there are additional configuration options for more advanced use cases.

## Configuration

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

## Adding Patches

### Using Flake Inputs

This is the fastest way in my opinion, because all you have to do is add a flake input. Updating flake inputs will also update your patches. Here are some examples:

```nix
# file: flake.nix
{
  inputs = {
    # ...

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

PRs can change over time, some commits might be added or replaced by a force-push.
To update only a single patch you can run `nix flake update nixpkgs-patch-git-review-bump` for example.
Running your usual flake update command like `nix flake update --commit-lock-file` will also update all patches.
If you use an "unstable" URL format like `https://github.com/NixOS/nixpkgs/pull/410328.diff`, you can get different patches at different time, or even different patches at the sime time on different machines because Nix already downloaded and cached the patch on one machine but not on the other.
To guarantee reproducibility, you can use the `https://github.com/NixOS/nixpkgs/commit/1123658f39e7635e8d10a1b0691d2ad310ac24fc.diff` format for single commits, or `https://github.com/NixOS/nixpkgs/compare/b024ced1aac25639f8ca8fdfc2f8c4fbd66c48ef...0330cef96364bfd90694ea782d54e64717aced63.diff` for a range of commits.
To be extra sure you can use download the patch and reference to it by a local path, or use a different method that requires specifying a hash (see below).

> [!NOTE]  
> Using URLs like `https://github.com/NixOS/nixpkgs/pull/410328.diff` is shorter and more convenient, but a few months ago this was heavily rate limited. If you run into such errors, you can use other formats mentioned above. 

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
            (fetchpatch2 {
              name = "git-review-bump.patch";
              url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
              hash = ""; # rebuild, wait for nix to fail and give you the hash, then put it here
            })
            (fetchpatch2 {
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
      (fetchpatch2 {
        name = "git-review-bump.patch";
        url = "https://github.com/NixOS/nixpkgs/pull/410328.diff";
        hash = ""; # rebuild, wait for nix to fail and give you the hash, then put it here
      })
    ];
  };
}
```

## Troubleshooting

When applying a patch fails, you'll see a similar message:

```console
Running phase: patchPhase
applying patch /nix/store/96pv6cq60v051g7ycx5dhr0k5jqw3j1f-nixpkgs-patch-git-review-bump
patching file pkgs/by-name/ha/halo/package.nix
Reversed (or previously applied) patch detected!  Assume -R? [n] 
Apply anyway? [n] 
Skipping patch.
1 out of 1 hunk ignored -- saving rejects to file pkgs/by-name/ha/halo/package.nix.rej
────────────────────────────────────────────────────────────────────────────────
Original file without any patches: /nix/store/qp6xsxincfqfy55crg851d1klw8vn8z4-source/./pkgs/by-name/ha/halo/package.nix
Failed hunks of this file:
--- pkgs/by-name/ha/halo/package.nix
+++ pkgs/by-name/ha/halo/package.nix
@@ -8,10 +8,10 @@
 }:
 stdenv.mkDerivation rec {
   pname = "halo";
-  version = "2.20.21";
+  version = "2.21.0";
   src = fetchurl {
     url = "https://github.com/halo-dev/halo/releases/download/v${version}/halo-${version}.jar";
-    hash = "sha256-hUR5zG6jr8u8pFaGcZJs8MFv+WBMm1oDo6zGaS4Y7BI=";
+    hash = "sha256-taEaHhPy/jR2ThY9Qk+cded3+LyZSNnrytWh8G5zqVE=";
   };
 
   nativeBuildInputs = [
────────────────────────────────────────────────────────────────────────────────
Applying some patches failed. Check the build log above this message.
Visit https://github.com/gepbird/nixpkgs-patcher#troubleshooting for help.
You can inspect the state of the patched nixpkgs by attaching to the build shell, or press Ctrl+C to exit:
build for nixpkgs-20250616.0917744-patched failed in patchPhase with exit code 1
To attach, run the following command:
    sudo /nix/store/y528s2cvrah7sgig54i97gnbq3nppikp-attach/bin/attach 7330040
```

Below there are some tips that helps you identify why applying the patch failed and how to fix it.

### Patch is Obsolete

It's possible that you previously included a PR that has already landed in your channel which is very likely when you see *Reversed (or previously applied) patch detected!*, in this case just delete this patch.

### Patch has a Merge Conflict

If you try to include a PR, on GitHub check for merge conflicts: whether it has a label called *2.status: merge conflict*, or *This branch has conflicts that must be resolved* at the bottom of the PR.
In that case you may want to notify the PR author to resolve these conflicts, then update your patch: for example `nix flake update nixpkgs-patch-halo-bump`. 

A conflict can also happen with multiple patches, for example 2 PRs editing the same files.
In that case you can try to [create an intermediate patch](#create-an-intermediate-patch) to include both PRs.

### Base Branch is Outdated

It's possible that a PR would cleanly apply for the target branch (usually master, staging or release-xx.xx branches), but your base branch is behind those (usually an older version of nixos-unstable, nixpkgs-unstable, nixos-xx.xx branches), in that case try updating your base branch.

Or find the dependant PRs and include them with patches, make sure to [order them correctly](#patches-are-out-of-order)!

Alternatively, try to [create an intermediate patch](#create-an-intermediate-patch).

### Patches are Out of Order

When you try to include multiple PRs, for example a package bump from v3 to v4, and another from v4 to v5, it's important that v3 to v4 patch gets applied first.
Patches are applied in alphabetical order, for clarity you can name the first patch `nixpkgs-patch-10-mypackage-v4` and the second `nixpkgs-patch-10-mypackage-v5`.
If you use patches from multiple sources, then it gets processed in this order: [flake inputs](#using-flake-inputs), [`nixpkgs-patcher.lib.nixosSystem` call](#using-nixpkgspatcher-config), [your configuration](#using-your-configuration).

### Attach to the Build Shell

At the end of the failure message you get a command which can be really helpful for debugging why did the patch fail.
To get started enter the command that you see there, for me it's:
```sh
sudo /nix/store/y528s2cvrah7sgig54i97gnbq3nppikp-attach/bin/attach 7330040
````

You can check which files did the patch fail for (but this is also printed in the above message):
```sh
bash-5.2# find -name *.rej 
./pkgs/by-name/ha/halo/package.nix.rej

bash-5.2# cat ./pkgs/by-name/ha/halo/package.nix.rej
--- pkgs/by-name/ha/halo/package.nix
+++ pkgs/by-name/ha/halo/package.nix
@@ -8,10 +8,10 @@
 }:
 stdenv.mkDerivation rec {
   pname = "halo";
-  version = "2.20.21";
+  version = "2.21.0";
   src = fetchurl {
     url = "https://github.com/halo-dev/halo/releases/download/v${version}/halo-${version}.jar";
-    hash = "sha256-hUR5zG6jr8u8pFaGcZJs8MFv+WBMm1oDo6zGaS4Y7BI=";
+    hash = "sha256-taEaHhPy/jR2ThY9Qk+cded3+LyZSNnrytWh8G5zqVE=";
   };
 
   nativeBuildInputs = [
```

More interestingly, you can check the original file:
```sh
bash-5.2# cat ./pkgs/by-name/ha/halo/package.nix
# part of the output is omitted
stdenv.mkDerivation rec {
  pname = "halo";
  version = "2.21.0";
  src = fetchurl {
    url = "https://github.com/halo-dev/halo/releases/download/v${version}/halo-${version}.jar";
    hash = "sha256-taEaHhPy/jR2ThY9Qk+cded3+LyZSNnrytWh8G5zqVE=";
  };
# part of the output is omitted
```

From the above 2 outputs, we can see that the patch expects to remove an older version (`-  version = "2.20.21";`), but the original file we have a newer version (`version = "2.21.0";`), this is a case when [the patch is obsolete](#patch-is-obsolete).

This was a simple patch failure, but you might come across more complex ones where this build shell can help you identify the issue, and later possibly [create an intermediate patch](#create-an-intermediate-patch).

### Create an Intermediate Patch

When you concluded that it makes sense to apply that specific version of the patch to a specific base nixpkgs, you should create an intermediate patch, which is applied before the failing patch.

Let's say you want to apply a [this Pocket ID bump PR](https://github.com/NixOS/nixpkgs/pull/411229) on a [slightly older nixos-unstable](https://github.com/NixOS/nixpkgs/commit/e06158e58f3adee28b139e9c2bcfcc41f8625b46).
You will get an error that it failed to apply a patch (with Pocket ID NixOS tests) but it has been [resolved in the PR](https://github.com/NixOS/nixpkgs/pull/411229#issuecomment-2912729915) by rebasing on top of the latest master.
If you're lucky, you can [bring your base more up-to-date](#base-branch-is-outdated) by including the dependant PR (in this case https://github.com/NixOS/nixpkgs/pull/410569), but unfortunately for this scenario it would create more conflicts as it was a treewide change affecting many files.
Taking only the relevant parts of the dependant PR or making your own from scratch will lead to something like this:

<details><summary>Content of nixpkgs-patch-10-pocket-id-test-migration.diff</summary>

```diff
diff --git a/nixos/tests/all-tests.nix b/nixos/tests/all-tests.nix
index c01da895fbbc12..2ba9260afff244 100644
--- a/nixos/tests/all-tests.nix
+++ b/nixos/tests/all-tests.nix
@@ -1057,7 +1057,7 @@ in
   pleroma = handleTestOn [ "x86_64-linux" "aarch64-linux" ] ./pleroma.nix { };
   plikd = handleTest ./plikd.nix { };
   plotinus = handleTest ./plotinus.nix { };
-  pocket-id = handleTest ./pocket-id.nix { };
+  pocket-id = runTest ./pocket-id.nix;
   podgrab = handleTest ./podgrab.nix { };
   podman = handleTestOn [ "aarch64-linux" "x86_64-linux" ] ./podman/default.nix { };
   podman-tls-ghostunnel = handleTestOn [
diff --git a/nixos/tests/pocket-id.nix b/nixos/tests/pocket-id.nix
index 753fa251473f4a..830ba3e8c7609c 100644
--- a/nixos/tests/pocket-id.nix
+++ b/nixos/tests/pocket-id.nix
@@ -1,47 +1,45 @@
-import ./make-test-python.nix (
-  { lib, ... }:
+{ lib, ... }:
 
-  {
-    name = "pocket-id";
-    meta.maintainers = with lib.maintainers; [
-      gepbird
-      ymstnt
-    ];
+{
+  name = "pocket-id";
+  meta.maintainers = with lib.maintainers; [
+    gepbird
+    ymstnt
+  ];
 
-    nodes = {
-      machine =
-        { ... }:
-        {
-          services.pocket-id = {
-            enable = true;
-            settings = {
-              PORT = 10001;
-              INTERNAL_BACKEND_URL = "http://localhost:10002";
-              BACKEND_PORT = 10002;
-            };
+  nodes = {
+    machine =
+      { ... }:
+      {
+        services.pocket-id = {
+          enable = true;
+          settings = {
+            PORT = 10001;
+            INTERNAL_BACKEND_URL = "http://localhost:10002";
+            BACKEND_PORT = 10002;
           };
         };
-    };
+      };
+  };
 
-    testScript =
-      { nodes, ... }:
-      let
-        inherit (nodes.machine.services.pocket-id) settings;
-        inherit (builtins) toString;
-      in
-      ''
-        machine.wait_for_unit("pocket-id-backend.service")
-        machine.wait_for_open_port(${toString settings.BACKEND_PORT})
-        machine.wait_for_unit("pocket-id-frontend.service")
-        machine.wait_for_open_port(${toString settings.PORT})
+  testScript =
+    { nodes, ... }:
+    let
+      inherit (nodes.machine.services.pocket-id) settings;
+      inherit (builtins) toString;
+    in
+    ''
+      machine.wait_for_unit("pocket-id-backend.service")
+      machine.wait_for_open_port(${toString settings.BACKEND_PORT})
+      machine.wait_for_unit("pocket-id-frontend.service")
+      machine.wait_for_open_port(${toString settings.PORT})
 
-        backend_status = machine.succeed("curl -L -o /tmp/backend-output -w '%{http_code}' http://localhost:${toString settings.BACKEND_PORT}/api/users/me")
-        assert backend_status == "401"
-        machine.succeed("grep 'You are not signed in' /tmp/backend-output")
+      backend_status = machine.succeed("curl -L -o /tmp/backend-output -w '%{http_code}' http://localhost:${toString settings.BACKEND_PORT}/api/users/me")
+      assert backend_status == "401"
+      machine.succeed("grep 'You are not signed in' /tmp/backend-output")
 
-        frontend_status = machine.succeed("curl -L -o /tmp/frontend-output -w '%{http_code}' http://localhost:${toString settings.PORT}")
-        assert frontend_status == "200"
-        machine.succeed("grep 'Sign in to Pocket ID' /tmp/frontend-output")
-      '';
-  }
-)
+      frontend_status = machine.succeed("curl -L -o /tmp/frontend-output -w '%{http_code}' http://localhost:${toString settings.PORT}")
+      assert frontend_status == "200"
+      machine.succeed("grep 'Sign in to Pocket ID' /tmp/frontend-output")
+    '';
+}
```
</details>

Then adding this local patch before the PR will fix the issue:

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs-patch-10-pocket-id-test-migration = {
      url = "nixpkgs-patch-10-pocket-id-test-migration.diff";
      flake = false;
    };
    nixpkgs-patch-20-pocket-id-dev = {
      url = "https://github.com/NixOS/nixpkgs/pull/411229.diff";
      flake = false;
    };
  }
}
```

## TODO

- work with other flake outputs, not just `nixosConfiguration`

## Comparison with Alternatives

This flake focuses on ease of use for patching nixpkgs and using it with NixOS.
It requires less effort to understand and quickly start using it compared to alternatives.
However, if you want to patch other flake inputs or use patches inside packages or devshells, check out the alternatives!

| | nixpkgs-patcher | [nix-patcher](https://github.com/katrinafyi/nix-patcher) | [flake-input-patcher](https://github.com/jfly/flake-input-patcher) |
|------------------------------                                               |----|----|----|
| Patches from flake inputs                                                   | ✅ | ✅ | ❌ |
| Patches using fetchpatch                                                    | ✅ | ❌ | ✅ |
| Patches in NixOS modules                                                    | ✅ | ❌ | ❌ |
| Local only                                                                  | ✅ | ❌ | ✅ |
| No extra eval time for local patching (cached)                              | ❌ | ✅ | ❌ |
| Doesn't require additional tools                                            | ✅ | ❌ | ✅ |
| Automatic `system` detection                                                | ✅ | ✅ | ❌ |
| Works for any flake on GitHub                                               | ❌ | ✅ | ✅ |
| Works for any flake                                                         | ❌ | ❌ | ✅ |
| [IFD](https://nix.dev/manual/nix/2.29/language/import-from-derivation) free | ❌ | ✅ | ❌ |

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
