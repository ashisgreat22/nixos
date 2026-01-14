# Proton CachyOS Auto-Updater Module (Home Manager)
# Provides: Auto-update timer for Proton CachyOS from GitHub releases
#
# Usage:
#   myModules.protonCachyosUpdater = {
#     enable = true;
#     arch = "x86_64_v3";
#     schedule = "daily";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.protonCachyosUpdater;

  updateScript = pkgs.writeShellScript "update-proton-cachyos" ''
        set -euo pipefail

        COMPAT_DIR="${cfg.compatToolsDir}"
        ARCH="${cfg.arch}"
        GITHUB_API="https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest"
        VERSION_FILE="$COMPAT_DIR/.proton-cachyos-version"

        # Ensure directory exists
        mkdir -p "$COMPAT_DIR"

        echo "=== Checking for Proton CachyOS updates ==="

        # Get latest release info from GitHub
        RELEASE_JSON=$(${pkgs.curl}/bin/curl -sL "$GITHUB_API")

        if [ -z "$RELEASE_JSON" ] || echo "$RELEASE_JSON" | ${pkgs.jq}/bin/jq -e '.message' > /dev/null 2>&1; then
          echo "Failed to fetch release info from GitHub"
          exit 1
        fi

        LATEST_TAG=$(echo "$RELEASE_JSON" | ${pkgs.jq}/bin/jq -r '.tag_name')
        echo "Latest version: $LATEST_TAG"

        # Check current version
        CURRENT_VERSION=""
        if [ -f "$VERSION_FILE" ]; then
          CURRENT_VERSION=$(cat "$VERSION_FILE")
        fi
        echo "Current version: ''${CURRENT_VERSION:-none}"

        if [ "$LATEST_TAG" = "$CURRENT_VERSION" ]; then
          echo "Already up to date!"
          # Still ensure symlink exists
          LATEST_DIR=$(ls -v "$COMPAT_DIR" | grep -E "^proton-cachyos" | grep -v "latest" | tail -1)
          if [ -n "$LATEST_DIR" ]; then
            ln -sfn "$COMPAT_DIR/$LATEST_DIR" "$COMPAT_DIR/proton-cachyos-latest"
          fi
          exit 0
        fi

        # Find download URL for our architecture
        DOWNLOAD_URL=$(echo "$RELEASE_JSON" | ${pkgs.jq}/bin/jq -r ".assets[] | select(.name | contains(\"$ARCH\")) | .browser_download_url" | grep "\.tar\.xz$" | head -1)

        if [ -z "$DOWNLOAD_URL" ]; then
          echo "No download found for architecture: $ARCH"
          exit 1
        fi

        FILENAME=$(basename "$DOWNLOAD_URL")
        echo "Downloading: $FILENAME"

        # Download to temp directory
        TEMP_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_DIR" EXIT

        ${pkgs.curl}/bin/curl -L --progress-bar -o "$TEMP_DIR/$FILENAME" "$DOWNLOAD_URL"

        echo "Extracting..."
        ${pkgs.gnutar}/bin/tar -xf "$TEMP_DIR/$FILENAME" -C "$COMPAT_DIR"

        # Find extracted directory name
        EXTRACTED_DIR=$(ls -v "$COMPAT_DIR" | grep -E "^proton-cachyos" | grep -v "latest" | tail -1)

        if [ -z "$EXTRACTED_DIR" ]; then
          echo "Failed to find extracted directory"
          exit 1
        fi

        echo "Installed: $EXTRACTED_DIR"

        # Create wrapper directory (remove old symlink/dir first)
        rm -rf "$COMPAT_DIR/proton-cachyos-latest"
        mkdir -p "$COMPAT_DIR/proton-cachyos-latest"

        # Create wrapper compatibilitytool.vdf
        # This allows Steam to see "proton-cachyos-latest" as a distinct tool pointing to the real files
        cat > "$COMPAT_DIR/proton-cachyos-latest/compatibilitytool.vdf" <<EOF
    "compatibilitytools"
    {
      "compat_tools"
      {
        "proton-cachyos-latest"
        {
          "install_path" "$COMPAT_DIR/$EXTRACTED_DIR"
          "display_name" "Proton CachyOS (Latest)"
          "from_oslist"  "windows"
          "to_oslist"    "linux"
        }
      }
    }
    EOF
        
        echo "Updated wrapper: proton-cachyos-latest -> $EXTRACTED_DIR"
        
        # Save version
        echo "$LATEST_TAG" > "$VERSION_FILE"
        
        echo "=== Update complete ==="
        ${pkgs.libnotify}/bin/notify-send "Proton CachyOS" "Updated to $LATEST_TAG" --icon=steam
  '';
in
{
  options.myModules.protonCachyosUpdater = {
    enable = lib.mkEnableOption "Proton CachyOS auto-updater";

    arch = lib.mkOption {
      type = lib.types.enum [
        "x86_64"
        "x86_64_v2"
        "x86_64_v3"
        "x86_64_v4"
      ];
      default = "x86_64_v3";
      description = "CPU architecture variant to download";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd calendar expression for update schedule";
    };

    randomDelay = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "Random delay before running update";
    };

    compatToolsDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/Steam/compatibilitytools.d";
      description = "Steam compatibility tools directory";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.proton-cachyos-update = {
      Unit = {
        Description = "Update Proton CachyOS from GitHub releases";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = updateScript;
        Environment = [
          "HOME=%h"
        ];
      };
    };

    systemd.user.timers.proton-cachyos-update = {
      Unit = {
        Description = "Proton CachyOS update timer";
      };

      Timer = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = cfg.randomDelay;
      };

      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
