# NixOS Modules Collection
# Reusable, modular NixOS configuration modules
#
# Usage:
#   # In flake.nix outputs
#   nixosModules = import ./modules;
#
#   # In configuration.nix
#   imports = [ ./modules ];
#   myModules.security.enable = true;
#   myModules.kernelHardening.enable = true;
#   # etc.

{ ... }:
{
  imports = [
    ./nixos
  ];
}
