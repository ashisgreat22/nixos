{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  options.myModules.performance = {
    enable = lib.mkEnableOption "system performance optimizations";
  };

  config = lib.mkIf config.myModules.performance.enable {
    services.scx = {
      enable = true;
      scheduler = "scx_lavd";
      package = pkgs.scx.full;
    };

    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };

    zramSwap = {
      enable = lib.mkForce true;
      algorithm = lib.mkForce "zstd";
      memoryPercent = lib.mkForce 100;
      priority = 100;
    };

    boot.kernel.sysctl = {
      "vm.swappiness" = lib.mkForce 180;
      "vm.watermark_boost_factor" = lib.mkForce 0;
      "vm.watermark_scale_factor" = lib.mkForce 125;
      "vm.page-cluster" = lib.mkForce 0;
      "vm.dirty_ratio" = lib.mkForce 10;
      "vm.dirty_background_ratio" = lib.mkForce 5;

      "net.core.somaxconn" = lib.mkForce 8192;
      "net.core.netdev_max_backlog" = lib.mkForce 16384;
      "net.ipv4.tcp_slow_start_after_idle" = lib.mkForce 0;
      "net.ipv4.tcp_rmem" = lib.mkForce "4096 1048576 2097152";
      "net.ipv4.tcp_wmem" = lib.mkForce "4096 65536 16777216";
    };

    powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

    # faster boot
    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
    systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

    services.irqbalance.enable = true;

    nix.settings = {
      max-jobs = "auto";
      cores = 0;
      log-lines = 25;
    };
  };
}
