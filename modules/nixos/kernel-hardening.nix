# Kernel Hardening Module
# Provides: hardened boot params, sysctl settings, blacklisted modules, ZRAM
#
# Usage:
#   myModules.kernelHardening = {
#     enable = true;
#     enableZram = true;       # default: true
#     zramPercent = 50;        # default: 50
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.kernelHardening;
in
{
  options.myModules.kernelHardening = {
    enable = lib.mkEnableOption "kernel hardening module";

    enableZram = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable ZRAM swap";
    };

    zramPercent = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Percentage of RAM to use for ZRAM";
    };

    zramAlgorithm = lib.mkOption {
      type = lib.types.str;
      default = "lz4";
      description = "Compression algorithm for ZRAM (lz4, zstd, lzo)";
    };

    tmpfsPercent = lib.mkOption {
      type = lib.types.str;
      default = "50%";
      description = "Size of /tmp tmpfs as percentage of RAM";
    };
  };

  config = lib.mkIf cfg.enable {
    # Secure boot loader settings
    boot.loader.systemd-boot.editor = false;

    # Use tmpfs for /tmp
    boot.tmp = {
      useTmpfs = true;
      tmpfsSize = cfg.tmpfsPercent;
    };

    # Runtime kernel hardening
    boot.kernelModules = lib.mkIf cfg.enableZram [ "zram" ];

    boot.kernelParams = [
      "slab_nomerge"
      "init_on_alloc=1"
      "init_on_free=1"
      "page_alloc.shuffle=1"
      "randomize_kstack_offset=on"
      "vsyscall=none"
      "oops=panic"
      "module.sig_enforce=1"
      "amd_iommu=on"
      "mitigations=auto"
      "lockdown=confidentiality"
    ];

    # Kernel sysctl hardening
    boot.kernel.sysctl = {
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "fs.protected_hardlinks" = 1;
      "fs.protected_symlinks" = 1;
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_rfc1337" = 1;
      "net.ipv4.ip_forward" = 1;
      "kernel.unprivileged_bpf_disabled" = 1;
      "kernel.kexec_load_disabled" = 1;
      "kernel.perf_event_paranoid" = 3;
      "net.ipv4.tcp_timestamps" = 0;
      "dev.tty.ldisc_autoload" = 0;
      "kernel.yama.ptrace_scope" = 1;
      "kernel.core_pattern" = "|/bin/false";
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.rp_filter" = 2;
      "net.ipv4.conf.default.rp_filter" = 2;
      "net.ipv4.conf.all.log_martians" = 1;
      "net.ipv4.conf.default.log_martians" = 1;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

      # Network optimization (TCP Buffers)
      "net.core.rmem_max" = 2500000;
      "net.core.wmem_max" = 2500000;
      "net.ipv4.tcp_rmem" = "4096 87380 2500000";
      "net.ipv4.tcp_wmem" = "4096 65536 2500000";
      "net.core.netdev_max_backlog" = 5000;

      # Advanced Security
      "net.core.bpf_jit_harden" = 2;
      "fs.suid_dumpable" = 0;
      "kernel.sysrq" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
    };

    # Set IO Scheduler to kyber for NVMe and bfq for SATA
    services.udev.extraRules = ''
      # NVMe
      ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="kyber"
      # SSD/HDD
      ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
      ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
    '';

    boot.blacklistedKernelModules = [
      "cramfs"
      "freevxfs"
      "jffs2"
      "hfs"
      "hfsplus"
      "udf"
      # DMA vulnerable modules
      "firewire-core"
      "firewire_ohci"
      "thunderbolt"
    ];

    security.lockKernelModules = true;

    zramSwap = lib.mkIf cfg.enableZram {
      enable = true;
      memoryPercent = cfg.zramPercent;
      algorithm = cfg.zramAlgorithm;
    };
  };
}
