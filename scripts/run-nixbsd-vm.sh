#!/usr/bin/env bash
# Script to build and run the NixBSD VM

set -e

echo "Building NixBSD VM..."
VM_PATH=$(nix build .#nixosConfigurations.nixbsd.config.system.build.vm --no-link --print-out-paths --extra-experimental-features 'nix-command flakes')

echo "Starting NixBSD VM..."
$VM_PATH/bin/run-nixbsd-vm
