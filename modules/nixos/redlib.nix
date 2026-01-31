# Redlib Module (Rootless Podman)
# Provides: Private Reddit frontend running in a rootless container
#
# Usage:
#   myModules.redlib = {
#     enable = true;
#     port = 8082;
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.redlib;
in
{
  options.myModules.redlib = {
    enable = lib.mkEnableOption "Redlib private Reddit frontend";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Port to expose Redlib on localhost";
    };
  };

  config = lib.mkIf cfg.enable {
    myModules.podman.enable = true;

    # Redlib Container
    virtualisation.oci-containers.containers."redlib" = {
      image = "quay.io/redlib/redlib:latest";
      # ports = [ "127.0.0.1:${toString cfg.port}:8080" ]; # Port exposed via VPN
      extraOptions = [
        "--pull=always"
        "--cap-drop=ALL"
        "--network=container:vpn"
      ];
      dependsOn = [ "vpn" ];
    };

    # Rootless Overrides
    systemd.services."podman-redlib".serviceConfig.User = lib.mkForce "ashie";
    systemd.services."podman-redlib".environment = {
      HOME = "/home/ashie";
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
    systemd.services."podman-redlib".serviceConfig.Type = lib.mkForce "simple";
    systemd.services."podman-redlib".serviceConfig.Delegate = true;
    systemd.services."podman-redlib".after = [
      "user-runtime-dir@1000.service"
      "podman-vpn.service"
    ];
    systemd.services."podman-redlib".requires = [
      "user-runtime-dir@1000.service"
      "podman-vpn.service"
    ];
  };
}
