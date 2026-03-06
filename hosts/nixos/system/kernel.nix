{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # nixpkgs.overlays = [
  #   inputs.nix-cachyos-kernel.overlays.default
  # ];
  # Use CachyOS Kernel
  # boot.kernelPackages =
  #   pkgs.linuxPackagesFor
  #     inputs.nix-cachyos-kernel.packages.${pkgs.system}.linux-cachyos-bore-lto;

  # =============================================================================
  # DEFAULT BOOT: Linux Desktop Mode (GPU for Host)
  # =============================================================================
  # This is the normal boot. The GPU is used by the host for Hyprland/gaming.

  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "split_lock_detect=off"
  ];

  # Vendor Reset (helps with GPU reset when switching modes)
  boot.extraModulePackages = [ config.boot.kernelPackages.vendor-reset ];
  boot.kernelModules = [
    "tcp_bbr"
    "vendor-reset"
    "ntsync"
    "wireguard"
    "af_packet"
    "bridge"
    "xt_tcpudp"
  ];

  # =============================================================================
  # Network and Misc Sysctl
  # =============================================================================
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    "vm.max_map_count" = 1048576;
    "user.max_user_namespaces" = 10000;
  };
}
