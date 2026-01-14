{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "uas"
    "usbhid"
    "sd_mod"
  ];

  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Unlock the encrypted root early in initrd (stable: UUID of the LUKS container)
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-uuid/362284b1-a1ab-4ad0-b87b-eba30eaa258d";
    # allowDiscards = true; # uncomment if you use SSD discard/TRIM through LUKS
  };

  # EFI System Partition
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/042E-DA9E";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/games" = {
    device = "/dev/mapper/cryptdata";
    fsType = "btrfs";
    options = [
      "subvol=@games"
      "compress-force=zstd"
      "noatime"
    ];
  };

  # Impermanence layout: persistent subvolumes that must be mounted in initrd
  fileSystems."/nix" = {
    device = lib.mkForce "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress-force=zstd"
      "noatime"
      "autodefrag"
    ];
    neededForBoot = true;
  };

  fileSystems."/persist" = {
    device = lib.mkForce "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [
      "subvol=@persist"
      "compress-force=zstd"
      "noatime"
      "autodefrag"
    ];
    neededForBoot = true;
  };

  # NOTE:
  # We intentionally do NOT define fileSystems."/" here because your setup appears to
  # use impermanence (root is typically tmpfs). If you *do* have a persistent root
  # subvolume, define it in your main config instead.

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot.swraid = {
    enable = true;
    mdadmConf = "PROGRAM ${pkgs.coreutils}/bin/true"; # Silences mdmon warning
  };
}
