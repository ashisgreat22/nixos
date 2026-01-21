# NixOS Configuration

Personal NixOS configuration with Hyprland, containerized services, and security hardening.

> **Note:** Parts of this configuration were created with the assistance of AI tools.

## Quick Start

```bash
# Apply configuration
doas nixos-rebuild switch --flake ~/nixos#nixos

# Update flake inputs
nix flake update

# Test configuration without applying
doas nixos-rebuild dry-run --flake ~/nixos#nixos
```

## Using These Modules

Others can import individual modules from this flake:

```nix
{
  inputs.ashie-nixos.url = "github:ashisgreat22/nixos";

  outputs = { nixpkgs, ashie-nixos, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        ashie-nixos.nixosModules.security
        ashie-nixos.nixosModules.kernelHardening
        {
          myModules.security.enable = true;
          myModules.kernelHardening.enable = true;
        }
      ];
    };
  };
}
```

### Available Modules

| Module                                  | Description                    |
| --------------------------------------- | ------------------------------ |
| `nixosModules.security`                 | doas, audit logging, AppArmor  |
| `nixosModules.kernelHardening`          | Boot params, sysctl, ZRAM      |
| `nixosModules.dnsOverTls`               | DNSSEC + DNS-over-TLS          |
| `nixosModules.cloudflareFirewall`       | nftables Cloudflare-only rules |
| `nixosModules.caddyCloudflare`          | Caddy with DNS-01 ACME         |
| `nixosModules.podman`                   | Podman container runtime       |
| `nixosModules.browserVpn`               | VPN-isolated browsers          |
| `homeManagerModules.hyprlandCatppuccin` | Themed Hyprland config         |
| `homeManagerModules.gluetunUser`        | Rootless VPN container         |
| `homeManagerModules.qbittorrentVpn`     | qBittorrent through VPN        |

## Structure

```
~/nixos/
├── configuration.nix      # Main config (enables modules via myModules.*)
├── flake.nix              # Flake inputs, outputs, and module exports
├── hardware-configuration.nix
├── home.nix               # Home Manager entry point
├── modules/               # Reusable NixOS modules
│   ├── default.nix        # Imports all system modules
│   ├── system/            # System-level modules
│   │   ├── security.nix          # doas, audit, AppArmor
│   │   ├── kernel-hardening.nix  # Boot params, sysctl, ZRAM
│   │   ├── dns-over-tls.nix      # DNSSEC + DoT
│   │   ├── cloudflare-firewall.nix  # nftables rules
│   │   ├── caddy-cloudflare.nix  # Caddy + DNS-01
│   │   ├── podman.nix            # Container runtime
│   │   └── browser-vpn.nix       # VPN-isolated browsers
│   └── home/              # Home Manager modules
│       ├── hyprland-catppuccin.nix
│       ├── gluetun-user.nix
│       ├── qbittorrent-vpn.nix
│       └── browser-container-update.nix
├── system/                # Host-specific system config
│   ├── boot.nix           # Bootloader
│   ├── hardware.nix       # GPU, USBGuard, fonts
│   ├── networking.nix     # Hostname, ddclient
│   ├── packages.nix       # System packages
│   ├── services.nix       # Steam, Caddy vhosts
│   └── secrets.nix        # SOPS secrets
├── home/                  # Host-specific Home Manager config
│   ├── fastfetch.nix, kitty.nix, steam.nix, vscode.nix
├── containers/            # Container Dockerfiles
│   ├── firefox-wayland/   # Isolated Firefox
│   ├── thorium-wayland/   # Isolated Thorium
│   └── tor-browser-wayland/
├── unified_router/        # API routing service
├── codex2api/             # Codex API proxy
├── antigravity-src/       # Antigravity2API source
└── secrets/               # SOPS-encrypted secrets
```

## Integrated Services

### API Ecosystem

A microservices architecture for managing LLM interactions:

- **Unified Router** (`unified_router/`)
- **Codex2API** (`codex2api/`)
- **Antigravity2API** (`antigravity-src/`)
- **Data Generator** (`scripts/data_generator/`): Tool for generating synthetic training data.

### Web Services (via Caddy)

| Service         | URL                   | Port        |
| --------------- | --------------------- | ----------- |
| Open WebUI      | `chat.ashisgreat.xyz` | 3000 → 8080 |
| Unified Router  | `api.ashisgreat.xyz`  | 6767        |
| Antigravity2API | (Internal)            | 8045        |

### Containers

```bash
# View running containers
podman ps

# View container logs
podman logs open-webui
podman logs antigravity2api
```

## Isolated Browsers (VPN)

Browsers running in containers routed through WireGuard VPN.

### Firefox

```bash
# Launch isolated Firefox
firefox-vpn-podman

# Or use commands directly
firefox-vpn-podman run      # Start Firefox
firefox-vpn-podman stop     # Stop containers
firefox-vpn-podman status   # Check status
firefox-vpn-podman build    # Rebuild container image
```

### Tor Browser

```bash
# Launch isolated Tor Browser
tor-browser-vpn-podman

# Or use commands directly
tor-browser-vpn-podman run      # Start Tor Browser
tor-browser-vpn-podman stop     # Stop containers
tor-browser-vpn-podman status   # Check status
tor-browser-vpn-podman build    # Rebuild container image
```

> **Note:** Traffic flows through both the VPN and Tor network for double isolation.

### Thorium Browser

```bash
# Launch isolated Thorium Browser
thorium-vpn-podman

# Or use commands directly
thorium-vpn-podman run      # Start Thorium
thorium-vpn-podman stop     # Stop containers
thorium-vpn-podman status   # Check status
thorium-vpn-podman build    # Rebuild container image
```

### Auto-Updates

Browser containers are automatically rebuilt weekly via systemd timer.

```bash
# Check timer status
systemctl --user status browser-containers-update.timer

# Manually trigger update
systemctl --user start browser-containers-update

# View update logs
journalctl --user -u browser-containers-update -n 50
```

## qBittorrent (VPN)

User service running through gluetun VPN container.

```bash
# Start/stop
systemctl --user start qbittorrent
systemctl --user stop qbittorrent

# View status
systemctl --user status gluetun
systemctl --user status qbittorrent

# Access WebUI (through VPN container)
# http://127.0.0.1:8080
```

## Secrets Management (SOPS)

Secrets are encrypted with AGE and decrypted at activation time.

```bash
# Edit secrets
sops secrets/secrets.yaml

# Add new secret to secrets.nix, then re-encrypt
sops updatekeys secrets/secrets.yaml
```

## Security Features & Hardening

### Kernel Hardening

**Boot Parameters** (runtime protection):

- `slab_nomerge` - Prevents slab cache merging
- `init_on_alloc/free=1` - Zeros memory (use-after-free mitigation)
- `page_alloc.shuffle=1` - Randomizes page allocator
- `randomize_kstack_offset=on` - Randomizes kernel stack
- `vsyscall=none` - Disables legacy vsyscall
- `oops=panic` - Panics on kernel oops

**Sysctl Settings**:

- `kptr_restrict=2` - Hide kernel pointers
- `dmesg_restrict=1` - Restrict kernel logs
- `ptrace_scope=1` - Restrict debugging
- `unprivileged_bpf_disabled=1` - Disable BPF for users

```bash
# Verify boot params after reboot
cat /proc/cmdline
```

### Network Security

- **DNS-over-TLS (DoT)**: Enabled via `systemd-resolved`. Encrypts all DNS queries to Quad9 and Cloudflare.
- **Firewall**: `nftables` with Cloudflare-only access on ports 80/443. Direct connections are blocked.
- **Caddy**: Uses DNS-01 ACME challenge (via Cloudflare API) for SSL certs. Configured with security headers (HSTS, CSP, etc.).

### Audit Logging

```bash
# View audit logs
sudo ausearch -ts today          # Today's events
sudo ausearch -k sudoers         # Sudoers changes
sudo aureport --summary          # Summary report
```

### Automatic Updates

- Runs daily at 4 AM
- Downloads updates but doesn't auto-reboot
- Apply manually: `sudo nixos-rebuild switch --flake ~/nixos#nixos`

### Known Security Considerations

- **Secrets**: `cloudflare.key` is currently a raw file, not managed by SOPS.
- **Containers**: Custom service containers may run as root internally.

## Useful Commands

```bash
# System
sudo nixos-rebuild switch --flake ~/nixos#nixos   # Apply config
sudo nixos-rebuild boot --flake ~/nixos#nixos     # Apply on next boot
nix flake update                                   # Update all inputs
nix-collect-garbage -d                            # Clean old generations

# Containers
podman system prune -a                            # Clean unused images
podman volume ls                                  # List volumes

# Firewall
sudo nft list ruleset                             # View nftables
sudo nft list set inet cloudflare cloudflare_ipv4 # View Cloudflare IPs

# Logs
journalctl -u caddy -f                            # Caddy logs
journalctl --user -u gluetun -f                   # VPN logs
```

## Troubleshooting

### Container network issues

```bash
# Recreate podman network
podman network rm antigravity-net
sudo systemctl restart podman-network-antigravity-net
```

### Firefox VPN not starting

```bash
# Check gluetun status first
systemctl --user status gluetun
journalctl --user -u gluetun -n 50

# Rebuild image if needed
firefox-vpn-podman build
```

### Secrets not decrypting

```bash
# Check SOPS key
ls -la ~/.config/sops/age/keys.txt
sops -d secrets/secrets.yaml  # Test decryption
```
