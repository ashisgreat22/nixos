#!/usr/bin/env bash
set -e

# Output file for the declarative script
OUTPUT_SCRIPT="/home/ashie/nixos/ensure_arr_users.sh"

echo "Capturing user from Sonarr..."

# Extract the first user row (assuming it's the admin)
# Format: ID|Identifier|Username|Password|Salt|Iterations
USER_ROW=$(nix run nixpkgs#sqlite -- /var/lib/nixarr/sonarr/sonarr.db "SELECT Identifier, Username, Password, Salt, Iterations FROM Users LIMIT 1;")

if [ -z "$USER_ROW" ]; then
    echo "No user found in Sonarr DB! Please create a user in the Web UI first."
    exit 1
fi

IFS='|' read -r IDENTIFIER USERNAME PASSWORD SALT ITERATIONS <<< "$USER_ROW"

echo "Found User: $USERNAME"

# Generate the script
cat <<EOF > "$OUTPUT_SCRIPT"
#!/usr/bin/env bash
set -e

# Function to ensure user exists
ensure_user() {
    SERVICE=\$1
    DB_PATH=\$2
    
    echo "Ensuring user '$USERNAME' exists in \$SERVICE..."
    
    # Check if user exists
    COUNT=\$(nix run nixpkgs#sqlite -- "\$DB_PATH" "SELECT count(*) FROM Users WHERE Username='$USERNAME';")
    
    if [ "\$COUNT" -eq "0" ]; then
        echo "Creating user '$USERNAME'..."
        nix run nixpkgs#sqlite -- "\$DB_PATH" "INSERT INTO Users (Identifier, Username, Password, Salt, Iterations) VALUES ('$IDENTIFIER', '$USERNAME', '$PASSWORD', '$SALT', '$ITERATIONS');"
    else
        echo "User '$USERNAME' already exists."
    fi
}

ensure_user "Sonarr" "/var/lib/nixarr/sonarr/sonarr.db"
ensure_user "Radarr" "/var/lib/nixarr/radarr/radarr.db"
ensure_user "Prowlarr" "/var/lib/nixarr/prowlarr/prowlarr.db"
# Jellyseerr uses a different DB structure, skipping for now (it likely synced via Jellyfin or has its own auth)

EOF

chmod +x "$OUTPUT_SCRIPT"
echo "Generated $OUTPUT_SCRIPT. You can now use this to ensure the user exists."
