#!/usr/bin/env bash
set -e

echo "Stopping services..."
systemctl stop sonarr radarr prowlarr

# Function to enable auth
enable_auth() {
    SERVICE=$1
    CONFIG_FILE=$2
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Enabling Forms Auth for $SERVICE..."
        cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
        
        # Set AuthenticationMethod to Forms
        if grep -q "<AuthenticationMethod>" "$CONFIG_FILE"; then
            sed -i 's|<AuthenticationMethod>.*</AuthenticationMethod>|<AuthenticationMethod>Forms</AuthenticationMethod>|g' "$CONFIG_FILE"
        else
            # Insert if missing (unlikely, but inside <Config> usually)
            sed -i 's|<Config>|<Config>\n  <AuthenticationMethod>Forms</AuthenticationMethod>|g' "$CONFIG_FILE"
        fi
        
        # Set AuthenticationRequired to Enabled (Correct Enum Value)
        if grep -q "<AuthenticationRequired>" "$CONFIG_FILE"; then
            sed -i 's|<AuthenticationRequired>.*</AuthenticationRequired>|<AuthenticationRequired>Enabled</AuthenticationRequired>|g' "$CONFIG_FILE"
        else
             # Insert
            sed -i 's|<Config>|<Config>\n  <AuthenticationRequired>Enabled</AuthenticationRequired>|g' "$CONFIG_FILE"
        fi
        
        echo "$SERVICE updated."
    else
        echo "Config for $SERVICE not found at $CONFIG_FILE"
    fi
}

enable_auth "Sonarr" "/var/lib/nixarr/sonarr/config.xml"
enable_auth "Radarr" "/var/lib/nixarr/radarr/config.xml"
enable_auth "Prowlarr" "/var/lib/nixarr/prowlarr/config.xml"

# Jellyseerr usually enforces login by default if users exist.
# Its config is in database, not easily scriptable via settings.json for auth mode.

echo "Restarting services..."
systemctl start sonarr radarr prowlarr

echo "Authentication enabled!"
echo "WARNING: If you do not have a user created in these apps, you may be locked out."
echo "If locked out, edit the config.xml file manually and set AuthenticationMethod back to 'None'."
