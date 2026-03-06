#!/usr/bin/env bash
# Convert kernel config to Nix structuredExtraConfig format
# Reads the generated kernel-config and outputs disabled options

CONFIG_FILE="/home/ashie/nixos/hosts/nixos/kernel-config"
OUTPUT_FILE="/home/ashie/nixos/hosts/nixos/kernel-config.nix"

echo "Converting $CONFIG_FILE to structuredExtraConfig format..."

# Start the Nix attribute set
cat > "$OUTPUT_FILE" << 'EOF'
# Auto-generated from kernel-config
# Run scripts/convert-kernel-config.sh to regenerate
{ lib }:
with lib.kernel;
{
EOF

# Extract disabled options 
grep "^# CONFIG_.*is not set" "$CONFIG_FILE" | while read -r line; do
    config_name=$(echo "$line" | sed 's/^# CONFIG_\(.*\) is not set$/\1/')
    if [[ "$config_name" =~ ^[0-9] ]]; then
        echo "  \"$config_name\" = lib.mkForce no;" >> "$OUTPUT_FILE"
    else
        echo "  $config_name = lib.mkForce no;" >> "$OUTPUT_FILE"
    fi
done


echo "}" >> "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE"
echo "Total disabled options: $(grep -c '= no;' "$OUTPUT_FILE")"
