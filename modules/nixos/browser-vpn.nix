# Browser VPN Isolation Module
# Provides: Isolated browsers (Firefox, Tor, Thorium, Kitty) running in Podman through VPN
#
# Usage:
#   myModules.browserVpn = {
#     enable = true;
#     browsers = [ "firefox" "tor-browser" "thorium" "kitty" ];  # default: all
#     gtkTheme = "Catppuccin-Frappe-Standard-Blue-Dark";
#     repositoryPath = "/home/user/nixos";  # Path to container Dockerfiles
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.browserVpn;

  # Helper function for auto-recovery from podman namespace corruption
  # Detects "cannot re-exec process" errors and runs migrate to fix
  podmanRecoveryHelper = ''
    podman_with_recovery() {
      local output
      local exit_code
      
      # First attempt
      output=$(podman "$@" 2>&1)
      exit_code=$?
      
      # Check for the namespace corruption error
      if echo "$output" | grep -q "cannot re-exec process to join the existing user namespace"; then
        echo "Detected stale podman namespace, running recovery..."
        podman system migrate 2>/dev/null || true
        sleep 1
        
        # Retry the command
        output=$(podman "$@" 2>&1)
        exit_code=$?
      fi
      
      echo "$output"
      return $exit_code
    }
  '';

  # Backend script generator for browsers
  # Firefox needs --security-opt=label=disable, others use --cap-drop=ALL
  mkBrowserBackend =
    name: containerName: imageName: dataVol: securityOpts: extraCmd:
    pkgs.writeShellScriptBin "${name}-vpn-backend" ''
      ACTION="$1"
      W_DISPLAY="$2"
      RUNTIME_DIR="$3"
      REPO_DIR="${cfg.repositoryPath}"

      ${podmanRecoveryHelper}

      case "$ACTION" in
        stop)
          echo "Stopping containers..."
          podman_with_recovery stop ${containerName} 2>/dev/null || true
          systemctl --user stop gluetun.service
          echo "Containers stopped."
          ;;
        status)
          echo "=== gluetun ===" 
          systemctl --user status gluetun.service --no-pager 2>/dev/null || echo "Not running (or service not found)"
          echo ""
          echo "=== ${containerName} ==="
          podman_with_recovery ps --filter name=${containerName} 2>/dev/null || echo "Not running"
          ;;
        build)
          echo "Building ${name} container..."
          podman_with_recovery build -t ${imageName}:latest "$REPO_DIR/containers/${name}-wayland/"
          echo "Build complete."
          ;;
        run)
          if ! podman_with_recovery image exists ${imageName}:latest 2>/dev/null; then
            echo "Building ${name} container image..."
            podman_with_recovery build -t ${imageName}:latest "$REPO_DIR/containers/${name}-wayland/"
          fi

          echo "Starting VPN container (user service)..."
          systemctl --user start gluetun.service
          
          echo "Waiting for VPN connection..."
          sleep 10
          
          echo "Starting ${name} with native Wayland (Rootless)..."
          podman_with_recovery run --rm -d \
            --name ${containerName} \
            --network=container:gluetun \
            ${securityOpts} \
            --userns=keep-id \
            --shm-size=2g \
            --device=/dev/dri \
            -v "$RUNTIME_DIR/$W_DISPLAY:/run/user/1000/$W_DISPLAY:ro" \
            -v "$RUNTIME_DIR/pipewire-0:/tmp/pipewire-0:ro" \
            -v "$RUNTIME_DIR/pulse:/tmp/pulse:ro" \
            -v /etc/machine-id:/etc/machine-id:ro \
            -e "WAYLAND_DISPLAY=$W_DISPLAY" \
            -e "XDG_RUNTIME_DIR=/run/user/1000" \
            -e "PULSE_SERVER=unix:/tmp/pulse/native" \
            -e "MOZ_ENABLE_WAYLAND=1" \
            -e "LIBGL_ALWAYS_SOFTWARE=1" \
            -e "MOZ_WEBRENDER=0" \
            -e "LD_PRELOAD=" \
            -v ${dataVol} \
            -e GTK_THEME=${cfg.gtkTheme} \
            -e "GSETTINGS_BACKEND=keyfile" \
            ${imageName}:latest \
            ${extraCmd}
          
          echo ""
          echo "${name} started! Window should appear on your desktop."
          ;;
        *)
          echo "Usage: ${name}-vpn-backend {stop|status|build|run} <DISPLAY> <RUNTIME_DIR>"
          exit 1
          ;;
      esac
    '';

  # Frontend wrapper script
  mkFrontendScript =
    name: backend:
    pkgs.writeShellScriptBin "${name}-vpn-podman" ''
      CMD="run"
      if [ -n "$1" ]; then
        CMD="$1"
      fi
      ${backend}/bin/${name}-vpn-backend \
        "$CMD" \
        "$WAYLAND_DISPLAY" \
        "$XDG_RUNTIME_DIR"
    '';

  # Desktop entry generator
  mkDesktopEntry = name: displayName: icon: category: keywords: ''
    cat > $out/share/applications/${name}-vpn.desktop << 'EOF'
    [Desktop Entry]
    Name=${displayName} (Isolated VPN)
    Comment=${displayName} with network isolation through VPN
    Exec=${name}-vpn-podman
    Icon=${icon}
    Terminal=false
    Type=Application
    Categories=${category};
    Keywords=${keywords};
    EOF
  '';

  # Firefox policies to disable IPv6 and force fast connections
  firefoxPolicies = pkgs.writeText "policies.json" (
    builtins.toJSON {
      policies = {
        DisableAppUpdate = true;
        DisableTelemetry = true;
        DisablePocket = true;
        DisableFirefoxStudies = true;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        Preferences = {
          "network.dns.disableIPv6" = true;
          "network.ipv6" = false;
          "network.http.fast-fallback-to-IPv4" = true;
          "network.trr.mode" = 5; # Disable DNS over HTTPS (use system/VPN DNS)
          "ui.systemUsesDarkTheme" = 1;
          "browser.theme.content-theme" = 0;
          "browser.theme.toolbar-theme" = 0;
          "browser.in-content.dark-mode" = true;
        };
      };
    }
  );

  # Browser configurations
  # Firefox needs label=disable for its internal sandbox to work
  firefoxBackend =
    mkBrowserBackend "firefox" "firefox-vpn" "localhost/firefox-wayland"
      "firefox-vpn-data:/home/firefox-user/.mozilla"
      "--security-opt=label=disable --security-opt=seccomp=unconfined -v ${firefoxPolicies}:/usr/lib/firefox/distribution/policies.json:ro"
      "";

  # Other browsers use --cap-drop=ALL for enhanced security
  torBrowserBackend =
    mkBrowserBackend "tor-browser" "tor-browser-vpn" "localhost/tor-browser-wayland"
      "tor-browser-vpn-data:/home/tor-user/tor-browser/Browser/TorBrowser/Data"
      "--cap-drop=ALL"
      "";

  thoriumBackend =
    mkBrowserBackend "thorium" "thorium-vpn" "localhost/thorium-wayland"
      "thorium-vpn-data:/home/thorium-user/.config/thorium"
      "--cap-drop=ALL"
      "thorium-browser --ozone-platform=wayland --enable-features=UseOzonePlatform --enable-gpu-rasterization --enable-zero-copy --no-sandbox";

  # Thorium Dev backend with custom browser flags for localhost-only access
  thoriumDevBackend = pkgs.writeShellScriptBin "thorium-dev-vpn-backend" ''
    ACTION="$1"
    W_DISPLAY="$2"
    RUNTIME_DIR="$3"
    REPO_DIR="${cfg.repositoryPath}"

    ${podmanRecoveryHelper}

    case "$ACTION" in
      stop)
        echo "Stopping containers..."
        podman_with_recovery stop thorium-dev-vpn 2>/dev/null || true
        systemctl --user stop gluetun.service
        echo "Containers stopped."
        ;;
      status)
        echo "=== gluetun ===" 
        systemctl --user status gluetun.service --no-pager 2>/dev/null || echo "Not running (or service not found)"
        echo ""
        echo "=== thorium-dev-vpn ==="
        podman_with_recovery ps --filter name=thorium-dev-vpn 2>/dev/null || echo "Not running"
        ;;
      build)
        echo "Building thorium-dev container..."
        podman_with_recovery build -t localhost/thorium-wayland:latest "$REPO_DIR/containers/thorium-wayland/"
        echo "Build complete."
        ;;
      run)
        if ! podman_with_recovery image exists localhost/thorium-wayland:latest 2>/dev/null; then
          echo "Building thorium-dev container image..."
          podman_with_recovery build -t localhost/thorium-wayland:latest "$REPO_DIR/containers/thorium-wayland/"
        fi

        echo "Starting VPN container (user service)..."
        systemctl --user start gluetun.service
        
        echo "Waiting for VPN connection..."
        sleep 5
        
        echo "Starting thorium-dev with native Wayland (Rootless) and localhost-only restrictions..."
        podman_with_recovery run --rm -d \
          --name thorium-dev-vpn \
          --network=container:gluetun \
          --cap-drop=ALL \
          --userns=keep-id \
          --shm-size=2g \
          --device=/dev/dri \
          -v "$RUNTIME_DIR/$W_DISPLAY:/tmp/$W_DISPLAY:ro" \
          -v "$RUNTIME_DIR/pipewire-0:/tmp/pipewire-0:ro" \
          -v "$RUNTIME_DIR/pulse:/tmp/pulse:ro" \
          -v /etc/machine-id:/etc/machine-id:ro \
          -e "WAYLAND_DISPLAY=$W_DISPLAY" \
          -e "XDG_RUNTIME_DIR=/tmp" \
          -e "PULSE_SERVER=unix:/tmp/pulse/native" \
          -e "MOZ_ENABLE_WAYLAND=1" \
          -v thorium-dev-vpn-data:/home/thorium-user/.config/thorium \
          -e GTK_THEME=${cfg.gtkTheme} \
          -e "GSETTINGS_BACKEND=keyfile" \
          localhost/thorium-wayland:latest \
          thorium-browser \
          --ozone-platform=wayland \
          --enable-features=UseOzonePlatform \
          --enable-gpu-rasterization \
          --enable-zero-copy \
          --no-sandbox \
          --proxy-server="http://127.0.0.1:65535" \
          --proxy-bypass-list="localhost;127.0.0.1;host.containers.internal;*.local"
        
        echo ""
        echo "thorium-dev started! Window should appear on your desktop."
        echo "This browser is restricted to localhost and host.containers.internal only."
        ;;
      *)
        echo "Usage: thorium-dev-vpn-backend {stop|status|build|run} <DISPLAY> <RUNTIME_DIR>"
        exit 1
        ;;
    esac
  '';

  # Kitty backend (special handling for config mounts)
  kittyBackend = pkgs.writeShellScriptBin "kitty-vpn-backend" ''
    ACTION="$1"
    W_DISPLAY="$2"
    RUNTIME_DIR="$3"
    REPO_DIR="${cfg.repositoryPath}"

    ${podmanRecoveryHelper}

    resolve_path() {
      realpath "$1"
    }

    case "$ACTION" in
      stop)
        echo "Stopping containers..."
        podman_with_recovery stop kitty-vpn 2>/dev/null || true
        systemctl --user stop gluetun.service
        echo "Containers stopped."
        ;;
      status)
        echo "=== gluetun ===" 
        systemctl --user status gluetun.service --no-pager 2>/dev/null || echo "Not running (or service not found)"
        echo ""
        echo "=== kitty-vpn ==="
        podman_with_recovery ps --filter name=kitty-vpn 2>/dev/null || echo "Not running"
        ;;
      build)
        echo "Building Arch Kitty container..."
        podman_with_recovery build -t localhost/arch-kitty:latest "$REPO_DIR/containers/arch-kitty/"
        echo "Build complete."
        ;;
      run)
        if ! podman_with_recovery image exists localhost/arch-kitty:latest 2>/dev/null; then
          echo "Building Arch Kitty container image..."
          podman_with_recovery build -t localhost/arch-kitty:latest "$REPO_DIR/containers/arch-kitty/"
        fi

        echo "Starting VPN container (user service)..."
        systemctl --user start gluetun.service
        
        echo "Waiting for VPN connection..."
        sleep 5
        
        KITTY_CONF_DIR="${cfg.kittyConfigDir}"
        KITTY_CONF_FILE="${cfg.kittyConfigDir}/kitty.conf"
        BASHRC_FILE="${cfg.bashrcPath}"
        
        REAL_KITTY_CONF=$(resolve_path "$KITTY_CONF_FILE")
        REAL_BASHRC=$(resolve_path "$BASHRC_FILE")
        
        echo "Starting Kitty with native Wayland (Rootless)..."
        podman_with_recovery run --rm -d \
          --name kitty-vpn \
          --network=container:gluetun \
          --cap-drop=ALL \
          --userns=keep-id \
          --shm-size=2g \
          --device=/dev/dri \
          -v "$RUNTIME_DIR/$W_DISPLAY:/tmp/$W_DISPLAY:ro" \
          -v "$RUNTIME_DIR/pipewire-0:/tmp/pipewire-0:ro" \
          -v "$RUNTIME_DIR/pulse:/tmp/pulse:ro" \
          -v /etc/machine-id:/etc/machine-id:ro \
          -v "$KITTY_CONF_DIR:/home/arch-user/.config/kitty:ro" \
          -v "$REAL_KITTY_CONF:/home/arch-user/.config/kitty/kitty.conf:ro" \
          -v "$REAL_BASHRC:/home/arch-user/.bashrc:ro" \
          -v arch-user-home:/home/arch-user \
          -e "WAYLAND_DISPLAY=$W_DISPLAY" \
          -e "XDG_RUNTIME_DIR=/tmp" \
          -e "PULSE_SERVER=unix:/tmp/pulse/native" \
          localhost/arch-kitty:latest
        
        echo ""
        echo "Kitty started! Window should appear on your desktop."
        ;;
      *)
        echo "Usage: kitty-vpn-backend {stop|status|build|run} <DISPLAY> <RUNTIME_DIR>"
        exit 1
        ;;
    esac
  '';

  # Build list of enabled browsers
  enabledPackages = lib.flatten [
    (lib.optional (builtins.elem "firefox" cfg.browsers) [
      firefoxBackend
      (mkFrontendScript "firefox" firefoxBackend)
    ])
    (lib.optional (builtins.elem "tor-browser" cfg.browsers) [
      torBrowserBackend
      (mkFrontendScript "tor-browser" torBrowserBackend)
    ])
    (lib.optional (builtins.elem "thorium" cfg.browsers) [
      thoriumBackend
      (mkFrontendScript "thorium" thoriumBackend)
    ])
    (lib.optional (builtins.elem "thorium-dev" cfg.browsers) [
      thoriumDevBackend
      (mkFrontendScript "thorium-dev" thoriumDevBackend)
    ])
    (lib.optional (builtins.elem "kitty" cfg.browsers) [
      kittyBackend
      (mkFrontendScript "kitty" kittyBackend)
    ])
  ];

  desktopEntriesPackage = pkgs.runCommand "browser-vpn-desktop-entries" { } ''
    mkdir -p $out/share/applications

    ${lib.optionalString (builtins.elem "firefox" cfg.browsers) (
      mkDesktopEntry "firefox" "Firefox" "firefox" "Network;WebBrowser" "browser;vpn;isolated;secure"
    )}
    ${lib.optionalString (builtins.elem "tor-browser" cfg.browsers) (
      mkDesktopEntry "tor-browser" "Tor Browser" "firefox" "Network;WebBrowser"
        "browser;vpn;isolated;secure;tor;onion"
    )}
    ${lib.optionalString (builtins.elem "thorium" cfg.browsers) (
      mkDesktopEntry "thorium" "Thorium" "chromium" "Network;WebBrowser"
        "browser;vpn;isolated;secure;chromium;thorium;privacy"
    )}
    ${lib.optionalString (builtins.elem "thorium-dev" cfg.browsers) (
      mkDesktopEntry "thorium-dev" "Thorium (Dev/Local)" "chromium" "Network;WebBrowser"
        "browser;vpn;isolated;secure;chromium;thorium;dev;local"
    )}
    ${lib.optionalString (builtins.elem "kitty" cfg.browsers) (
      mkDesktopEntry "kitty" "Kitty" "kitty" "System;TerminalEmulator" "terminal;vpn;isolated;kitty;arch"
    )}
  '';

in
{
  options.myModules.browserVpn = {
    enable = lib.mkEnableOption "VPN-isolated browser containers";

    browsers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "firefox"
          "tor-browser"
          "thorium"
          "thorium-dev"
          "kitty"
        ]
      );
      default = [
        "firefox"
        "tor-browser"
        "thorium"
        "thorium-dev"
        "kitty"
      ];
      description = "Which browsers to enable";
    };

    gtkTheme = lib.mkOption {
      type = lib.types.str;
      default = "Catppuccin-Mocha-Standard-Blue-Dark";
      description = "GTK theme for browsers";
    };

    repositoryPath = lib.mkOption {
      type = lib.types.str;
      default = config.myModules.system.repoPath;
      description = "Path to repository containing container Dockerfiles";
    };

    kittyConfigDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/.config/kitty";
      description = "Path to kitty configuration directory";
    };

    bashrcPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/.bashrc";
      description = "Path to bashrc file for Kitty container";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = enabledPackages ++ [ desktopEntriesPackage ];
  };
}
