{ lib, ... }:

{
  fileSystems."/" = {
    device = "nodev";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
