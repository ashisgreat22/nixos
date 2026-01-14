{
  config,
  pkgs,
  lib,
  ...
}:
{
  # ============================================
  # Enable Modular Components
  # ============================================
  myModules = {
    # Global Settings
    system.repoPath = "/home/ashie/nixos";

    # Security hardening (doas, audit, AppArmor)
    security = {
      enable = true;
      useDoas = true;
      enableAudit = false;
      enableAppArmor = true;
      enableFail2Ban = false;
    };

    # Kernel hardening (boot params, sysctl, ZRAM)
    kernelHardening = {
      enable = true;
      enableZram = true;
      zramPercent = 100;
      zramAlgorithm = "zstd";
    };

    # Secure Boot (Lanzaboote)
    # 1. sudo sbctl create-keys
    # 2. sudo sbctl enroll-keys -m
    # 3. Enable this option
    # 4. Reboot
    secureBoot = {
      enable = false; # Disabled for initial install (enable after running sbctl create-keys)
      pkiBundle = "/var/lib/sbctl";
    };

    # DNS-over-TLS with DNSSEC
    dnsOverTls = {
      enable = true;
      dnssec = true;
    };

    # Cloudflare-only firewall rules
    cloudflareFirewall = {
      enable = false;
      enablePodmanWorkaround = false;
      restrictedPorts = [
        80
        443
      ];
    };

    # Base Podman container runtime
    # Disabled here because system/podman.nix handles Podman + container definitions
    podman.enable = true;

    # VPN-isolated browser containers
    browserVpn = {
      enable = true;
      browsers = [
        "firefox"
        "tor-browser"
        "thorium"
        "thorium-dev"
        "kitty"
      ];
    };

    # Ollama System Service (Isolated)
    ollamaRocm = {
      enable = false; # Disabled temporarily to unblock install (namespace issues)
    };

    # Open WebUI System Service (Isolated)
    openWebUI = {
      enable = true;
    };
  };
}
