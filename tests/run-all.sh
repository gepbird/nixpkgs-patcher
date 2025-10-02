#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix
set -x
for testDir in */; do
  pushd $testDir
  nix run github:NixOS/nixpkgs#nixVersions.stable -- build .#checks.x86_64-linux.tests
  # TODO: fix "error: lock file contains mutable lock '{"path":"../..","type":"path"}'"
  #nix run github:NixOS/nixpkgs#lixPackageSets.stable.lix -- build .#checks.x86_64-linux.tests
  popd
done
