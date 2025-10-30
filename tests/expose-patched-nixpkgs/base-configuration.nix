{ lib, ... }:

{
  fileSystems."/" = {
    device = "nodev";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.loader.grub.device = "nodev";

  system.stateVersion = "25.05";
}
