# Proton CachyOS Auto-Updater Module (Home Manager)
# Provides: Auto-update timer for Proton CachyOS from GitHub releases
# Now supports both Steam and Lutris

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

        # Path where we store the real Proton files
        # We default to Steam's compat tools dir as it typically lives on a game drive
        STORAGE_DIR="${cfg.steam.compatToolsDir}"
        ARCH="${cfg.arch}"
        GITHUB_API="https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest"
        VERSION_FILE="$STORAGE_DIR/.proton-cachyos-version"

        # Ensure storage directory exists
        mkdir -p "$STORAGE_DIR"

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

        update_links() {
          local versioned_dir="$1"
          
          # Steam Integration
          if [ "${if cfg.steam.enable then "1" else "0"}" = "1" ]; then
            echo "Updating Steam wrapper: $STORAGE_DIR/proton-cachyos-latest"
            rm -rf "$STORAGE_DIR/proton-cachyos-latest"
            mkdir -p "$STORAGE_DIR/proton-cachyos-latest"
            cat > "$STORAGE_DIR/proton-cachyos-latest/compatibilitytool.vdf" <<EOF
    "compatibilitytools"
    {
      "compat_tools"
      {
        "proton-cachyos-latest"
        {
          "install_path" "$STORAGE_DIR/$versioned_dir"
          "display_name" "Proton CachyOS (Latest)"
          "from_oslist"  "windows"
          "to_oslist"    "linux"
        }
      }
    }
    EOF
          fi

          # Lutris Integration
          if [ "${if cfg.lutris.enable then "1" else "0"}" = "1" ]; then
            local runners_dir="${cfg.lutris.runnersDir}"
            echo "Updating Lutris symlink: $runners_dir/proton-cachyos-latest"
            mkdir -p "$runners_dir"
            ln -sfn "$STORAGE_DIR/$versioned_dir" "$runners_dir/proton-cachyos-latest"
          fi
        }

        if [ "$LATEST_TAG" = "$CURRENT_VERSION" ]; then
          echo "Already up to date!"
          # Still ensure links exist and are correct
          LATEST_DIR=$(ls -v "$STORAGE_DIR" | grep -E "^proton-cachyos" | grep -v "latest" | tail -1)
          if [ -n "$LATEST_DIR" ]; then
            update_links "$LATEST_DIR"
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
        ${pkgs.gnutar}/bin/tar -xf "$TEMP_DIR/$FILENAME" -C "$STORAGE_DIR"

        # Find extracted directory name
        EXTRACTED_DIR=$(ls -v "$STORAGE_DIR" | grep -E "^proton-cachyos" | grep -v "latest" | tail -1)

        if [ -z "$EXTRACTED_DIR" ]; then
          echo "Failed to find extracted directory"
          exit 1
        fi

        echo "Installed: $EXTRACTED_DIR"
        
        # Update links for Steam and Lutris
        update_links "$EXTRACTED_DIR"
        
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

    steam = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam integration (creates compatibilitytool.vdf wrapper)";
      };
      compatToolsDir = lib.mkOption {
        type = lib.types.str;
        default = "$HOME/.local/share/Steam/compatibilitytools.d";
        description = "Steam compatibility tools directory (also used as primary storage)";
      };
    };

    lutris = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Lutris integration (creates symlink in runners directory)";
      };
      runnersDir = lib.mkOption {
        type = lib.types.str;
        default = "$HOME/.local/share/lutris/runners/wine";
        description = "Lutris wine runners directory";
      };
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
