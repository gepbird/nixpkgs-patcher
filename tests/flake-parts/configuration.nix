{ pkgs, ... }:

{
  boot.loader.grub.device = "nodev";

  environment.systemPackages = with pkgs; [
    git-review
  ];

  system.stateVersion = "25.05";
}
