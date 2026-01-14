{
  config,
  pkgs,
  inputs,
  ...
}:
{
  # ============================================
  # Enable Modular Components
  # ============================================
  myModules = {
    # Global Settings
    common.repoPath = "/home/ashie/nixos";

    # Catppuccin-themed Hyprland (Disabled)
    hyprlandCatppuccin = {
      enable = false;
      # Settings kept for reference
      keyboardLayout = "de";
      keyboardVariant = "nodeadkeys";
      keyboardModel = "pc105";
      primaryMonitor = "DP-2";
      primaryResolution = "2560x1440@165";
      secondaryMonitor = "HDMI-A-1";
      secondaryResolution = "1920x1080@60";
    };

    # Niri Configuration
    niri = {
      enable = true;
      keyboardLayout = "de";
      keyboardVariant = "nodeadkeys";
      primaryMonitor = "DP-2";
      primaryResolution = "2560x1440@165";
      secondaryMonitor = "HDMI-A-1";
      secondaryResolution = "1920x1080@60";
    };

    # Gluetun VPN user service
    gluetunUser = {
      enable = true;
      environmentFile = "/run/secrets/rendered/gluetun.env";
    };

    # qBittorrent through VPN
    qbittorrentVpn = {
      enable = true;
      configDir = "/home/ashie/qbittorrent/config";
      downloadsDir = "/home/ashie/qbittorrent/downloads";
    };

    # Auto-update browser containers
    browserContainerUpdate = {
      enable = true;
    };

    # Auto-update Proton CachyOS from GitHub
    protonCachyosUpdater = {
      enable = true;
      arch = "x86_64_v3";
    };

    # Unified API Router
    # unifiedRouter = {
    #   enable = true;
    #   environmentFile = "/home/ashie/nixos/unified-router/.env";
    # };

    # SillyTavern Frontend
    sillytavern = {
      enable = true;
    };

    # Noctalia Shell
    noctalia = {
      enable = true;
    };
  };
}
