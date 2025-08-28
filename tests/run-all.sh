#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix
set -x
for testDir in */; do
  pushd $testDir
  nix run github:NixOS/nixpkgs#nixVersions.stable -- flake check
  # TODO: fix "error: lock file contains mutable lock '{"path":"../..","type":"path"}'"
  #nix run github:NixOS/nixpkgs#lixPackageSets.stable.lix -- flake check
  popd
done
