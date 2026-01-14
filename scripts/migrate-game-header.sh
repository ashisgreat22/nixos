#!/usr/bin/env bash
set -e

# CONSTANTS
DISK_ID="/dev/disk/by-id/nvme-KINGSTON_SNVS1000G_50026B7784BF8876"
HEADER_FILE="/persist/etc/cryptdata.header"
MAPPER_NAME="cryptdata"

echo "========================================================"
echo "LUKS DETACHED HEADER MIGRATION"
echo "Target Disk: $DISK_ID"
echo "Header File: $HEADER_FILE"
echo "========================================================"
echo ""
echo "WARNING: This process isolates the encryption header from the disk."
echo "1. If you lose $HEADER_FILE, your data is GONE FOREVER."
echo "2. The disk will appear as random noise to anyone inspecting it."
echo ""

if [ -f "$HEADER_FILE" ]; then
    echo "ERROR: Header file $HEADER_FILE already exists. Aborting to prevent overwrite."
    exit 1
fi

if [ ! -e "$DISK_ID" ]; then
    echo "ERROR: Target disk $DISK_ID not found."
    exit 1
fi

read -p "Type 'DETACH' to proceed with backing up and WIPING the header from the disk: " confirm
if [ "$confirm" != "DETACH" ]; then
    echo "Aborting."
    exit 1
fi

echo ""
echo "[1/3] Backing up LUKS header..."
doas cryptsetup luksHeaderBackup "$DISK_ID" --header-backup-file "$HEADER_FILE"

if [ ! -s "$HEADER_FILE" ]; then
    echo "ERROR: Header file creation failed or is empty."
    exit 1
fi
echo "Header saved to $HEADER_FILE"
doas chmod 600 "$HEADER_FILE"

echo ""
echo "[2/3] Verifying header backup (dry-run open)..."
# We try to dump parameters from the file to ensure it's valid
if ! doas cryptsetup luksDump "$HEADER_FILE" > /dev/null; then
    echo "ERROR: The backup header appears invalid. Aborting wipe."
    rm "$HEADER_FILE"
    exit 1
fi
echo "Header backup looks valid."

echo ""
echo "[3/3] WIPING header from physical disk..."
# This is the point of no return for the disk's standalone validity
doas cryptsetup luksErase "$DISK_ID"

echo ""
echo "SUCCESS! The header is now detached."
echo "You must now update your NixOS configuration to use 'header=$HEADER_FILE'."
echo "UUIDs on the raw device are now gone. Use the /dev/disk/by-id/ path."
