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
  mainUser = config.myModules.system.mainUser;
  mainUserUid = toString config.users.users.${mainUser}.uid;
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
      labels = { "io.containers.autoupdate" = "registry"; };
      # ports = [ "127.0.0.1:${toString cfg.port}:8080" ]; # Port exposed via VPN
      extraOptions = [
        "--pull=always"
        "--cap-drop=ALL"
        "--network=container:vpn"
      ];
      dependsOn = [ "vpn" ];
    };

    # Rootless Overrides
    systemd.services."podman-redlib".serviceConfig.User = lib.mkForce mainUser;
    systemd.services."podman-redlib".environment = {
      HOME = "/home/${mainUser}";
      XDG_RUNTIME_DIR = "/run/user/${mainUserUid}";
    };
    systemd.services."podman-redlib".serviceConfig.Type = lib.mkForce "simple";
    systemd.services."podman-redlib".serviceConfig.Delegate = true;
    systemd.services."podman-redlib".after = [
      "user-runtime-dir@${mainUserUid}.service"
      "podman-vpn.service"
    ];
    systemd.services."podman-redlib".requires = [
      "user-runtime-dir@${mainUserUid}.service"
      "podman-vpn.service"
    ];
  };
}