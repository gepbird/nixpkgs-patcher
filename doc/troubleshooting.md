### Error Message

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
