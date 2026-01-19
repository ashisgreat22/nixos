#!/usr/bin/env bash
# Convert COMPLETE kernel config to Nix structuredExtraConfig format
# Reads the generated kernel-config and outputs ALL options

CONFIG_FILE="/home/ashie/nixos/hosts/nixos/kernel-config"
OUTPUT_FILE="/home/ashie/nixos/hosts/nixos/kernel-config.nix"

echo "Converting $CONFIG_FILE to structuredExtraConfig format (FULL)..."

# Start the Nix attribute set
cat > "$OUTPUT_FILE" << 'EOF'
# Auto-generated from kernel-config (FULL)
# Run scripts/convert-kernel-config.sh to regenerate
{ lib }:
with lib.kernel;
{
EOF

# Process line by line
declare -A seen_keys
while read -r line; do
    # Skip empty lines and comments that are not "is not set"
    if [[ -z "$line" ]]; then continue; fi
    if [[ "$line" =~ ^#\ .*is\ not\ set$ ]]; then
        # Handle "is not set"
        key=$(echo "$line" | sed 's/^# CONFIG_\(.*\) is not set$/\1/')
        val="no"
    elif [[ "$line" =~ ^CONFIG_ ]]; then
        # Handle "CONFIG_KEY=VALUE"
        # Extract key and value. Value is everything after first =
        key=$(echo "$line" | cut -d= -f1 | sed 's/^CONFIG_//')
        val=$(echo "$line" | cut -d= -f2-)
    else
        # Skip other lines (comments etc)
        continue
    fi

    # Formatting logic
    
    # 1. Quote key if it starts with digit
    if [[ "$key" =~ ^[0-9] ]]; then
        nix_key="\"$key\""
    else
        nix_key="$key"
    fi

    # 2. Convert value to Nix format
    if [[ "$val" == "no" ]]; then
        nix_val="no"
    elif [[ "$val" == "y" ]]; then
        nix_val="yes"
    elif [[ "$val" == "m" ]]; then
        nix_val="module"
    elif [[ "$val" == "\"\"" ]]; then
        nix_val="(freeform \"\")"
    elif [[ "$val" =~ ^\" ]]; then
        # It's a string literal "foo". 
        # NixOS kernel config usually likes freeform for arbitrary strings to avoid type issues.
        # Let's wrap it in freeform just like we do for numbers/bare words.
        # But wait, val already has quotes. So val is "\"foo\"".
        # freeform expects a string. so (freeform "\"foo\"") is correct? 
        # Actually (freeform "foo") is probably what we want if we strip quotes?
        # No, freeform value is written AS IS to .config.
        # So if .config has CONFIG_FOO="bar", we want freeform "\"bar\"".
        # So we keep the quotes in val.
        nix_val="(freeform $val)"
    else
        # It's a number, hex, or bare word. Wrap in freeform.
        nix_val="(freeform \"$val\")"
    fi

    # Output with mkForce
    if [[ -z "${seen_keys[$nix_key]}" ]]; then
        echo "  $nix_key = lib.mkForce $nix_val;" >> "$OUTPUT_FILE"
        seen_keys["$nix_key"]=1
    fi

done < "$CONFIG_FILE"

# Close the attribute set
echo "}" >> "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE"
echo "Total options: $(grep -c '=' "$OUTPUT_FILE")"
