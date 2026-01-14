{ pkgs, ... }:
{
  # Disable systemd-boot
  boot.loader.systemd-boot.enable = false;

  # Enable GRUB
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = false;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;

  # Boot Animation (Plymouth)
  boot.plymouth.enable = true;

  # Catppuccin Theme Configuration
  catppuccin.flavor = "mocha";
  catppuccin.grub.enable = true;
  catppuccin.plymouth.enable = true;
}
