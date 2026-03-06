# NixOS Configuration

A modular, security-hardened NixOS flake featuring multiple desktop environments (Niri, Cosmic), sophisticated application sandboxing via `nix-bwrapper`, and a containerized service ecosystem.

## 🛡️ Core Pillars

- **Security Hardening**: Aggressive kernel parameters, DNS-over-TLS, AppArmor, and an `nftables` firewall with Cloudflare-specific rules.
- **Application Sandboxing**: Granular isolation for browsers, games, and proprietary apps using `bubblewrap` via a custom `nix-bwrapper` framework.
- **Modular Architecture**: A clean `myModules` namespace that decouples configuration logic from host-specific implementation.
- **Modern Desktop**: Support for **Niri** (scrollable tiling) and **Cosmic** (Epoch), with **Noctalia** shell integration.

---

## 🚀 Quick Start

```bash
# Apply system configuration
doas nixos-rebuild switch --flake .#nixos

# Update all flake inputs
nix flake update

# Check active security parameters
cat /proc/cmdline
sudo nft list ruleset
```

---

## 🏗️ Repository Structure

```text
/home/ashie/nixos/
├── flake.nix              # Entry point & input management
├── hosts/nixos/           # Host-specific configurations
│   ├── configuration.nix  # System entry point
│   ├── default.nix        # Enabled system modules (myModules.*)
│   ├── home-modules.nix   # Enabled HM modules (myModules.*)
│   └── home.nix           # Home Manager entry point
├── modules/               # Reusable logic
│   ├── nixos/             # System modules (Hardening, Podman, etc.)
│   └── home-manager/      # User modules (DEs, Tools, Services)
├── containers/            # Dockerfiles for isolated environments
└── secrets/               # SOPS-encrypted secrets (AGE)
```

---

## 📦 Modular System (`myModules`)

This flake uses a unified module system. You can toggle features in `hosts/nixos/default.nix` (system) and `hosts/nixos/home-modules.nix` (user).

### Key System Modules
| Module | Description | Status |
| :--- | :--- | :--- |
| `security` | AppArmor, doas, and system audit | Enabled |
| `kernelHardening` | Sysctl & boot-time mitigations | Enabled |
| `dnsOverTls` | Encrypted DNS via systemd-resolved | Enabled |
| `cloudflareFirewall` | nftables rules restricted to CF IPs | Enabled |
| `podman` | OCI container runtime | Enabled |
| `ollamaRocm` | Local LLM acceleration for AMD GPUs | Enabled |

### Key User Modules
| Module | Description | Status |
| :--- | :--- | :--- |
| `niri` | Scrollable tiling window manager | **Active** |
| `cosmic` | System76's modern desktop environment | Available |
| `noctalia` | Custom shell and UI components | Enabled |
| `protonCachyos` | Auto-updating gaming runtime | Enabled |

---

## 🔒 Application Sandboxing

Applications are wrapped in `bubblewrap` namespaces using the `mkSandboxedApp` utility (see `modules/nixos/sandbox-utils.nix`). This ensures:
- **No Home Access**: Apps only see specific, required directories.
- **D-Bus Isolation**: Access to the system/session bus is filtered via `xdg-dbus-proxy`.
- **Resource Limiting**: Isolated `/proc`, `/dev`, and `/sys` nodes.

### Sandboxed Applications
- **Browsers**: Firefox, Brave, Tor Browser, Thorium.
- **Gaming**: Steam, Prism Launcher, Lutris.
- **Social**: Vesktop (Discord), Spotify, Tutanota.

---

## 🛠️ Integrated Services

- **SearXNG**: Privacy-focused search engine at `search.ashisgreat.xyz`.
- **Antigravity2API**: LLM API proxy.
- **Ollama**: Local AI inference backend with ROCm support.
- **Redlib**: Privacy-friendly Reddit front-end.
- **OpenClaw**: Modern AI Agent

---

## 🔐 Secrets Management

Secrets are managed via **SOPS** and encrypted with **AGE**.
- **Edit secrets**: `sops secrets/secrets.yaml`
- **Key location**: `~/.config/sops/age/keys.txt`

---

## 🧹 Maintenance

```bash
# Clean old system generations
nix-collect-garbage -d

# Optimize the nix store
nix store optimise

# View container status
podman ps -a
```
