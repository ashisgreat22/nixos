#!/usr/bin/env bash
set -e

# Only run if /games/steam is a mountpoint to verify we aren't deleting the only copy
if ! mountpoint -q /games/steam; then
    echo "CRITICAL ERROR: /games/steam is NOT a mountpoint."
    echo "This implies the migration didn't apply correctly or the subvolume isn't mounted."
    echo "Aborting cleanup to prevent data loss."
    exit 1
fi

if [ "$EUID" -ne 0 ]; then 
  echo "Please run this script with doas: doas $0"
  exit 1
fi

cd /games || exit 1

echo "Starting cleanup of old Steam files in /games..."
echo "Preserving: 3DS, Switch, battlenet, and the 'steam' mountpoint."

# Iterate over all files/dirs, including hidden ones
for item in * .[^.]*; do
    # Skip . and ..
    if [[ "$item" == "." || "$item" == ".." ]]; then continue; fi

    case "$item" in
        "3DS"|"Switch"|"battlenet"|"steam")
            echo "  [KEEP] $item"
            ;;
        *)
            echo "  [DELETE] $item"
            rm -rf "$item"
            ;;
    esac
done

echo "Cleanup complete. /games now contains only non-Steam games and the 'steam' directory."
