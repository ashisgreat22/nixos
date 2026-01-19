#!/usr/bin/env bash
set -e

# Configuration
SOURCE_DIR="/games"
TARGET_MOUNT="/mnt/new_steam"
BTRFS_ROOT_MOUNT="/mnt/btrfs_root"
DEVICE="/dev/mapper/cryptdata"
SUBVOL_NAME="@steam"
USER_OWNER="ashie"
GROUP_OWNER="users"

# Ensure we are running with doas or root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run this script with doas: doas $0"
  exit 1
fi

echo "Starting Steam migration..."

# 1. Mount Btrfs root
mkdir -p "$BTRFS_ROOT_MOUNT"
echo "Mounting btrfs root..."
mount -o subvolid=5 "$DEVICE" "$BTRFS_ROOT_MOUNT"

# 2. Create subvolume
if [ -d "$BTRFS_ROOT_MOUNT/$SUBVOL_NAME" ]; then
    echo "Subvolume $SUBVOL_NAME already exists."
else
    echo "Creating subvolume $SUBVOL_NAME..."
    btrfs subvolume create "$BTRFS_ROOT_MOUNT/$SUBVOL_NAME"
fi

# 3. Mount new subvolume
mkdir -p "$TARGET_MOUNT"
echo "Mounting new subvolume to $TARGET_MOUNT..."
mount -o subvol="$SUBVOL_NAME" "$DEVICE" "$TARGET_MOUNT"

# 4. Copy files with reflink (instant copy)
echo "Copying files from $SOURCE_DIR to $TARGET_MOUNT..."
shopt -s dotglob
for item in "$SOURCE_DIR"/*; do
    name=$(basename "$item")
    case "$name" in
        "3DS"|"Switch"|"battlenet")
            echo "Skipping $name"
            ;;
        *)
            echo "Moving $name..."
            cp --reflink=always -r "$item" "$TARGET_MOUNT/"
            ;;
    esac
done

# 5. Set permissions
echo "Setting permissions..."
chown -R "$USER_OWNER":"$GROUP_OWNER" "$TARGET_MOUNT"

# 6. Unmount
echo "Unmounting..."
umount "$TARGET_MOUNT"
umount "$BTRFS_ROOT_MOUNT"
rmdir "$TARGET_MOUNT" "$BTRFS_ROOT_MOUNT"

echo "Migration data copy complete."
echo "Please verify the contents if possible."
echo ""
echo "NEXT STEPS:"
echo "1. Run 'nixos-rebuild switch' to apply the new hardware-configuration.nix changes."
echo "2. Once verified, you can manually delete the old files in /games to free up space (the space is currently shared via reflink, so deleting won't free space until the old refs are gone, but it cleans up the folder view)."
echo "   Example: doas rm -rf /games/steamfiles..."
