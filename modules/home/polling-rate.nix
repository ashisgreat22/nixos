{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.polling-rate-switcher;

  switcherScript = pkgs.writeShellScriptBin "polling-rate-switcher" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.jq
        pkgs.systemd
        pkgs.niri
        pkgs.gawk
      ]
    }:$PATH"

    # Find the Razer device object path via D-Bus
    # We look for an object path that looks like /org/razer/device/...
    # AND supports setPollRate
    echo "Searching for OpenRazer device on D-Bus..."

    RAZER_OBJ=""

    # Simple retry loop in case the service starts before the device is ready
    for i in {1..10}; do
        # Find matches, then check introspection for setPollRate method
        CANDIDATES=$(busctl --user tree --list org.razer | grep '^/org/razer/device/') || true
        
        for obj in $CANDIDATES; do
            if busctl --user introspect org.razer "$obj" 2>/dev/null | grep -q "setPollRate"; then
                RAZER_OBJ="$obj"
                break
            fi
        done

        if [ -n "$RAZER_OBJ" ]; then
            break
        fi
        sleep 2
    done

    if [ -z "$RAZER_OBJ" ]; then
      echo "No Razer device found on D-Bus org.razer that supports setPollRate after retries."
      exit 1
    fi

    echo "Found Razer device at $RAZER_OBJ"

    # Function to set polling rate via D-Bus
    set_rate() {
      local rate="$1"
      # Call OpenRazer method: setPollRate(int)
      busctl --user call org.razer "$RAZER_OBJ" razer.device.misc setPollRate i "$rate"
    }

    current_rate=""

    # Listen to Niri event stream
    # We filter for WindowFocusChanged events, then query the state.
    # This avoids parsing the complex event stream directly for state.
    niri msg --json event-stream | jq --unbuffered -c 'select(.WindowFocusChanged) | .WindowFocusChanged.id' | while read -r _; do
      # Query current focused window
      # The focused-window output is wrapped in Ok.FocusedWindow
      fw=$(niri msg --json focused-window 2>/dev/null || true)
      
      # If no window is focused or command fails, these will be empty
      app_id=$(echo "$fw" | jq -r '.Ok.FocusedWindow.app_id // ""' | tr '[:upper:]' '[:lower:]')
      title=$(echo "$fw" | jq -r '.Ok.FocusedWindow.title // ""' | tr '[:upper:]' '[:lower:]')

      # Default rate
      target_rate=1000

      # High polling rate for specific games
      if [[ "$app_id" == *"overwatch"* || "$title" == *"overwatch"* ]]; then
        target_rate=8000
      fi

      if [ "$target_rate" != "$current_rate" ]; then
        echo "Switching rate to $target_rate Hz (App: $app_id, Title: $title)"
        set_rate "$target_rate"
        current_rate="$target_rate"
      fi
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
