{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  boot.initrd.supportedFilesystems = [ "btrfs" ];
  boot.initrd.systemd.enable = true;

  systemd.tmpfiles.rules = [
    "h /persist/var/lib/containers - - - - +C"
    "h /persist/var/lib/ollama - - - - +C"
  ];

  fileSystems."/etc/ssh" = {
    device = "/persist/etc/ssh";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd" # Random seed and other systemd state
      "/var/lib/systemd/coredump"
      "/var/log/journal" # Journald logs (binary format)
      "/var/log" # Text logs (optional but good for legacy)
      "/var/lib/containers" # Podman/Docker images and containers
      "/var/lib/ollama" # LLM models
      "/var/lib/open-webui" # Chat history
      "/var/lib/acme" # Let's Encrypt SSL certs (nginx)
      "/var/lib/tailscale" # Tailscale identity
      "/var/lib/bluetooth" # Bluetooth pairings
      "/var/lib/sbctl" # Secure Boot Keys
      "/etc/NetworkManager/system-connections" # Wifi/Ethernet profiles
      "/var/lib/qbittorrent"
      "/var/lib/nixarr"
      "/var/lib/nixflix"
      "/var/lib/authelia-main"
    ];

    files = [
      "/etc/machine-id"
    ];

    users.ashie = {
      directories = [
        "Downloads"
        "Documents"
        "Music"
        "Pictures"
        "Videos"
        "src/aadniz-searxng"
        "Torrents"
        "nixos" # Config repo
        ".local/share/PrismLauncher" # Minecraft
        ".local/share/containers" # Rootless podman
        ".config/BraveSoftware" # Browser profile
        ".mozilla" # Firefox profile
        ".ssh" # User SSH keys
        ".gnupg" # GPG keys
        ".gemini" # AI Assistant State
        "git" # Git Repositories
        ".local/state" # Application State
        ".config/Antigravity" # Antigravity Config
        ".config/modprobed-db" # Local modconfig database
        ".config/VSCodium" # Codium Config
        ".config/sops" # Sops keys
        ".config/easyeffects"
        ".config/gh" # Github CLI Auth
        ".local/share/keyrings" # Gnome Keyrings (Passwords)
        ".local/share/nvim" # NeoVim data (LazyVim, Mason, etc.)
        ".local/share/flatpak" # Flatpak Apps
        ".vscode" # VSCode Extensions
        ".vscode-oss" # VSCodium Extensions
        ".config/lutris"
        ".local/share/lutris"
        ".local/share/Larian Studios"
        ".config/citron"
        ".local/share/citron"
        ".cache/lutris"
        ".config/azahar"
        ".local/share/azahar"
        ".config/Citron"
        ".local/share/Citron"
        ".local/share/umu"
        ".cache/mesa_shader_cache"
        # ".local/share/Steam" # Symlinked to /games/Steam (Already Persistent)
        ".paradoxlauncher"
        ".local/share/Paradox Interactive"
        ".steam" # Steam Symlinks and logs
        ".config/steamtinkerlaunch" # Example of extra tools
        ".local/share/applications" # Desktop entries
        ".local/share/icons" # Application icons
        ".local/bin" # User scripts
        ".local/share/qBittorrent"
        ".local/share/jellyfin-desktop"
        ".cache/jellyfin-desktop"
        ".local/share/zoxide"
        ".local/share/fish"
        "fabric-docs-mcp"
      ];
      files = [
      ];
    };
  };
}
