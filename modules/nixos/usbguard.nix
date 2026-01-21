# USBGuard Module
# Provides: Policy enforcement for USB devices
#
# Usage:
#   myModules.usbguard = {
#     enable = true;
#     generatePolicy = true; # Auto-generate policy from currently connected devices
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.usbguard;
in
{
  options.myModules.usbguard = {
    enable = lib.mkEnableOption "USBGuard for USB device control";

    generatePolicy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Generate an initial policy from currently connected devices on activation (requires reboot/service restart)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.usbguard = {
      enable = true;
      dbus.enable = true;
      
      # Block new devices by default
      implicitPolicyTarget = "block";
      
      # Treat present devices as allowed (until policy is generated)
      presentDevicePolicy = "apply-policy"; # or "keep" or "allow"
    };

    # Helper script to generate policy
    environment.systemPackages = lib.mkIf cfg.generatePolicy [
      (pkgs.writeShellScriptBin "generate-usbguard-policy" ''
        sudo usbguard generate-policy > /etc/usbguard/rules.conf
        sudo systemctl restart usbguard
        echo "USBGuard policy generated from connected devices."
      '')
    ];
  };
}
