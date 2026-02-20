{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.hostPlatform = "x86_64-freebsd";

  # NixBSD doesn't have systemd, it uses FreeBSD's init or similar.
  # The NixBSD modules handle the specific FreeBSD configuration.

  networking.hostName = "nixbsd";

  # Default user configuration
  users.users.ashie = {
    isNormalUser = true;
    description = "Ashie";
    extraGroups = [ "wheel" ];
    initialPassword = "nixbsd";
  };

  # SSH service for access
  services.sshd.enable = true;

  # FreeBSD loader configuration
  boot.loader.stand-freebsd.enable = true;

  # File system layout
  fileSystems."/" = {
    device = "/dev/gpt/nixos";
    fsType = "ufs";
  };

  fileSystems."/boot" = {
    device = "/dev/msdosfs/ESP";
    fsType = "msdosfs";
  };

  # VM variant for running in QEMU
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 2048; # 2GB RAM
      cores = 2;
    };
  };
}
