{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # Noctalia shell
  # Noctalia shell
  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    ydotool
  ];

  environment.etc."glfw".source = "${pkgs.glfw}/lib";

  boot.kernelModules = [
    "uinput"
  ];
  users.groups.uinput = { };
  users.users.ashie.extraGroups = [ "uinput" ];

  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
  '';

  # FORCE Root Filesystem to satisfy assertions
  fileSystems."/" = lib.mkForce {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=16G"
      "mode=755"
    ];
  };

  imports = [
    ./default.nix # Host-specific configuration
    ./hardware-configuration.nix
    ./system/boot.nix # Boot loader settings (non-hardening parts)
    ./system/networking.nix # Host-specific networking (hostname, ddclient)
    ./system/hardware.nix # Hardware-specific (GPU, USBGuard, fonts)
    ./system/services.nix # Host-specific services (Steam, Caddy vhosts)
    ./system/packages.nix # Package list
    ./system/users.nix # User accounts
    ./system/greetd.nix # Display manager
    ../../modules/nixos/cosmic.nix # Cosmic Desktop
    ./system/kernel.nix # CachyOS kernel
    ./system/locate.nix # mlocate
    ./system/secrets.nix # SOPS secrets
    ./system/compatibility.nix # Compatibility layers (nix-ld)
    ./system/game-drive.nix
    ./system/vpn-namespace.nix # Isolated VPN Namespace
    #./system/authelia.nix # SSO/2FA
    ../../modules/nixos/media.nix # Arr Stack
    ../../modules/nixos/steam-gamemode.nix # Steam GameMode Session
  ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-original"
      "steam-run"
      "spotify"
      "antigravity"
      "vscode-extension-bmewburn-vscode-intelephense-client"
      "claude-code"
      "steam-unwrapped"
    ];
  hardware.enableRedistributableFirmware = true;

  # Enable Fish shell
  programs.fish.enable = true;

  # Enable Gamemode
  programs.gamemode.enable = true;

  # Disable command-not-found to prevent info leaks
  programs.command-not-found.enable = false;

  # Git security exception for flakes
  programs.git = {
    enable = true;
    config.safe.directory = "/home/ashie/nixos";
  };

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "04:00";
    flake = "/home/ashie/nixos#nixos";
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "de_DE.UTF-8/UTF-8"
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.allowed-users = [ "ashie" ];
  nix.settings.sandbox = true;

  # Automatic Garbage Collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Binary caches for CachyOS kernel
  nix.settings.substituters = [
    "https://hyprland.cachix.org"
    "https://nix-community.cachix.org"
    "https://attic.xuyh0120.win/lantian"
    "https://cache.garnix.io"
  ];
  nix.settings.trusted-public-keys = [
    "cache.cachyos.org-1:j9qLlx+z0OYBtCqflh9v4I+5fsljqG5l2/C9t0yY18q="
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  ];

  # Registry pinning for instant shell startups
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.channel.enable = false; # We are using flakes

  # Enable performance optimizations
  myModules.performance.enable = true;

  system.stateVersion = "25.05";
}
