{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
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
    ./system/kernel.nix # CachyOS kernel
    ./system/locate.nix # mlocate
    ./system/secrets.nix # SOPS secrets
    ./system/compatibility.nix # Compatibility layers (nix-ld)
    ./system/game-drive.nix

    ./system/authelia.nix # SSO/2FA

    # Modularized configs
    ./system/noctalia.nix
    ./system/filesystems.nix
    ./system/nix-settings.nix
    ./system/locale.nix
  ];

  # Enable performance optimizations
  myModules.performance.enable = true;
  services.resolved.dnssec = "false";
  # Enable modularized components
  myModules.desktop.cosmic.enable = true;
  myModules.media.enable = true;
  myModules.gaming.gamemode.enable = true;
  myModules.redlib.enable = true;
  services.openclaw-service.enable = true;
  services.my-proxies.litellm.enable = true;

  # Enable sandboxed applications
  myModules.wireproxy = {
    enable = true;
    endpointIP = "94.228.209.212";
  };
  myModules.steamSandboxed.enable = true;
  myModules.lutrisSandboxed.enable = true;
  myModules.firefoxSandboxed = {
    enable = true;
    useProxy = true;
  };
  myModules.braveSandboxed = {
    enable = true;
    useProxy = true;
  };
  myModules.azaharSandboxed.enable = true;
  myModules.faugusSandboxed.enable = true;
  myModules.citronSandboxed.enable = true;
  myModules.ryubingSandboxed.enable = true;
  myModules.spotifySandboxed.enable = true;
  myModules.vesktopSandboxed.enable = true;
  myModules.tutanotaSandboxed.enable = true;
  myModules.prismlauncherSandboxed.enable = true;

  system.stateVersion = "25.05";
}
