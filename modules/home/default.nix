# Home Manager Modules Index
# Import this to get all home-manager modules
#
# Usage in home.nix:
#   imports = [ ./modules/home ];

{ ... }:
{
  imports = [
    ./common.nix
    ./hyprland-catppuccin.nix
    ./niri.nix
    ./gluetun-user.nix
    ./qbittorrent-vpn.nix
    ./browser-container-update.nix
    ./proton-cachyos-updater.nix
    ./cli-tools.nix
    ./nixvim.nix

    # ./unified-router.nix
    ./sillytavern.nix

    ./niri.nix
    ./noctalia.nix
    ./polling-rate.nix
    ./antigravity2api.nix
    ./theme.nix
    ./prismlauncher.nix
  ];
}
