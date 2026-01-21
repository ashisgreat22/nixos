#!/usr/bin/env bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  # Re-run as root, preserving environment
  # doas automatically preserves some env, allowing specific ones if configured, 
  # but for simplicity we rely on the internal command to handle env variables.
  exec doas "$0" "$@"
fi

NAMESPACE="vpn"
USER="ashie" # Hardcoded for now, could be dynamic

# Check if namespace exists
if ! ip netns list | grep -q "$NAMESPACE"; then
  echo "Error: Network namespace '$NAMESPACE' does not exist."
  echo "Ensure vpn-netns.service is running."
  exit 1
fi

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <command> [args...]"
  exit 1
fi

# Execute in namespace as the user
# We use `doas -u $USER` INSIDE the namespace to drop back to user privileges
# We MUST explicitly pass environment variables because doas cleans them.
# The bwrapper needs HOME, XDG_RUNTIME_DIR, etc. to function correctly.
exec ip netns exec "$NAMESPACE" doas -u "$USER" env \
  HOME="/home/$USER" \
  USER="$USER" \
  XDG_RUNTIME_DIR="/run/user/$(id -u $USER)" \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $USER)/bus" \
  "$@"
