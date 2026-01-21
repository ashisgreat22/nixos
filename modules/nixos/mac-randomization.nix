# MAC Address Randomization Module
# Provides: MAC address randomization for Wi-Fi and Ethernet
#
# Usage:
#   myModules.macRandomization = {
#     enable = true;
#     mode = "stable-ssid";  # "random", "stable", "stable-ssid" (default)
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.macRandomization;
in
{
  options.myModules.macRandomization = {
    enable = lib.mkEnableOption "MAC address randomization";

    mode = lib.mkOption {
      type = lib.types.enum [ "random" "stable" "stable-ssid" ];
      default = "stable-ssid";
      description = ''
        MAC randomization mode:
        - random: Randomize for every connection (highest privacy, might break captive portals).
        - stable: Generate a stable random MAC per connection profile.
        - stable-ssid: Generate a stable random MAC per SSID (default).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.wifi.macAddress = cfg.mode;
    
    # Optional: Ethernet randomization (can cause issues on some LANs)
    # networking.networkmanager.ethernet.macAddress = cfg.mode;
  };
}
