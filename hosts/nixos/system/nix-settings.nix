{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      antigravity = prev.antigravity.overrideAttrs (oldAttrs: rec {
        version = "1.18.3";
        src = prev.fetchurl {
          url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.18.3-4739469533380608/linux-x64/Antigravity.tar.gz";
          sha256 = "0f4n3i45gjr36hidpvibzn3p2jla2r7wg91ybmf2akafjn6f8zsc";
        };
      });
    })
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

  # Disable command-not-found to prevent info leaks
  programs.command-not-found.enable = false;

  # Git security exception for flakes
  programs.git = {
    enable = true;
    config.safe.directory = "/home/ashie/nixos";
  };

  # Automatic Updates (System + Containers)
  myModules.autoUpdate.enable = true;

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
}
