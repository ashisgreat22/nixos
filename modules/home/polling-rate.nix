{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.polling-rate-switcher;

  switcherScript = pkgs.writeShellScriptBin "polling-rate-switcher" ''
    # Find Razer Viper V3 Pro sysfs path
    # Look for a device that supports poll_rate
    MOUSE_PATH=""

    find_mouse() {
      for dev in /sys/bus/hid/drivers/razermouse/*; do
        if [ -f "$dev/device_type" ] && [ -f "$dev/poll_rate" ]; then
          TYPE=$(cat "$dev/device_type")
          # Check if it looks like a mouse "Razer Viper V3 Pro" usually has unique ID/Type
          # For now, we take the first Razer device that supports polling rate
          # Or specifically filter if we knew exact string.
          # The user said "Active window... polling rate of my razer viper v3 pro"
          # We'll assume it's the main device found.
          MOUSE_PATH="$dev"
          echo "Found Razer device at $MOUSE_PATH ($TYPE)"
          break
        fi
      done
    }

    find_mouse

    if [ -z "$MOUSE_PATH" ]; then
      echo "No Razer mouse found with poll_rate capability."
      exit 1
    fi

    echo "Starting Polling Rate Switcher for $MOUSE_PATH"

    CURRENT_MODE="unknown"

    update_rate() {
      TARGET=$1
      # Read current to avoid redundant writes
      CURRENT=$(cat "$MOUSE_PATH/poll_rate")
      
      if [ "$CURRENT" != "$TARGET" ]; then
        echo "Switching polling rate to $TARGET Hz"
        echo "$TARGET" > "$MOUSE_PATH/poll_rate"
      fi
    }

    while true; do
      # Get active window info from Niri
      # Niri msg active-window returns JSON
      WINDOW_INFO=$(${pkgs.niri}/bin/niri msg -j focused-window 2>/dev/null)
      
      if [ -n "$WINDOW_INFO" ]; then
        APP_ID=$(echo "$WINDOW_INFO" | ${pkgs.jq}/bin/jq -r '.app_id // ""' | tr '[:upper:]' '[:lower:]')
        TITLE=$(echo "$WINDOW_INFO" | ${pkgs.jq}/bin/jq -r '.title // ""' | tr '[:upper:]' '[:lower:]')
        
        # Check for Overwatch
        if [[ "$APP_ID" == *"overwatch"* ]] || [[ "$TITLE" == *"overwatch"* ]]; then
          update_rate 8000
        else
          update_rate 1000
        fi
      fi
      
      sleep 2
    done
  '';
in
{
  options.services.polling-rate-switcher = {
    enable = lib.mkEnableOption "Polling Rate Switcher Service";
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.polling-rate-switcher = {
      Unit = {
        Description = "Auto-switch Razer Polling Rate for Overwatch";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${switcherScript}/bin/polling-rate-switcher";
        Restart = "always";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
