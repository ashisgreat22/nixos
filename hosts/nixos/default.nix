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

    hardenedMalloc = {
      enable = false;
    };

    secureBoot = {
      enable = false; # switched to grub, needs update
      pkiBundle = "/var/lib/sbctl";
    };

    dnsOverTls = {
      enable = true;
      dnssec = true;
    };

    cloudflareFirewall = {
      enable = true;
      allowLocalTraffic = true;
      enablePodmanWorkaround = true;
      publicPorts = [
        # Ports that are public
        443
        80
      ];
      restrictedPorts = [ ]; # Ports that are Cloudflare only
    };

    podman.enable = true;

    browserVpn = {
      enable = false;
      browsers = [
        "firefox"
        "tor-browser"
        "thorium"
        "thorium-dev"
        "kitty"
      ];
    };

    ollamaRocm = {
      enable = false; # Disabled temporarily to unblock install (namespace issues)
    };

    openWebUI = {
      enable = false;
    };

    searxng = {
      enable = true;
      port = 8888;
      domain = "search.ashisgreat.xyz";
      donations = {
        "Monero" =
          "https://trocador.app/en/anonpay/?ticker_to=xmr&network_to=Mainnet&address=86piV4MV8wqSCTv3innkL1cMP54oShHfmVhq6QcFgvtuFTJqw6FkMgm4hgTaxV3reqXVmfGW5h5ffZanLM5XzW4nHUReno4&donation=True&simple_mode=True&amount=1.1e-05&name=Ashie&bgcolor=00000000";
      };
    };
  };
}
