# System Modules Index
# Import this to get all system modules
#
# Usage in configuration.nix:
#   imports = [ ./modules/system ];

{ ... }:
{
  imports = [
    ./common.nix
    ./security.nix
    ./mac-randomization.nix
    ./usbguard.nix
    ./kernel-hardening.nix
    ./secure-boot.nix
    ./dns-over-tls.nix
    ./cloudflare-firewall.nix
    ./sched-ext.nix
    ./caddy-cloudflare.nix
    ./podman.nix
    ./browser-vpn.nix
    ./ollama-rocm.nix
    ./open-webui.nix
    ./lutris-sandboxed.nix
    ./firefox-sandboxed.nix
    ./brave-sandboxed.nix
    ./prismlauncher-sandboxed.nix
    ./steam-sandboxed.nix
    ./azahar-sandboxed.nix
    ./faugus-sandboxed.nix
    ./citron-sandboxed.nix
    ./ryubing-sandboxed.nix
    ./spotify-sandboxed.nix
    ./performance.nix
    ./vesktop-sandboxed.nix
    ./tutanota-sandboxed.nix
    ./hardened-malloc.nix
    ./searxng.nix
  ];
}
