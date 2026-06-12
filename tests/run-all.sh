#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix

system="$(nix-instantiate --eval --raw -E 'builtins.currentSystem')"

for testDir in */; do
  pushd "$testDir" || exit 1

  # Check if this test defines checks for the current system; skip if not
  if [ "$(nix eval --impure --expr "(builtins.getFlake (toString ./.)).checks ? \"$system\"" 2>/dev/null)" = true ]; then
    nix run github:NixOS/nixpkgs#nixVersions.stable -- build ".#checks.$system.tests"
    # TODO: fix "error: lock file contains mutable lock '{"path":"../..","type":"path"}'"
    #nix run github:NixOS/nixpkgs#lixPackageSets.stable.lix -- build ".#checks.$system.tests"
    echo "Finished $testDir"
  else
    echo "Skipping $testDir (no checks for system '$system')"
  fi

  popd &> /dev/null || exit 1
done
