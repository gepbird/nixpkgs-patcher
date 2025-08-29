{ pkgs, ... }:

{
  boot.loader.grub.device = "nodev";

  environment.systemPackages = with pkgs; [
    msmtp
  ];

  system.stateVersion = "25.05";
}
