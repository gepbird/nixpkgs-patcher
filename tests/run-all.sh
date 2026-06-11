#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix
set -x

system="$(nix-instantiate --eval --raw -E 'builtins.currentSystem')"

for testDir in */; do
  pushd $testDir
  nix run github:NixOS/nixpkgs#nixVersions.stable -- build .#checks.$system.tests
  # TODO: fix "error: lock file contains mutable lock '{"path":"../..","type":"path"}'"
  #nix run github:NixOS/nixpkgs#lixPackageSets.stable.lix -- build .#checks.$system.tests
  popd
done
