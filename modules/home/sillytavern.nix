# SillyTavern Module (Home Manager)
# Provides: SillyTavern as rootless container
#
# Usage:
#   myModules.sillytavern = {
#     enable = true;
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.sillytavern;
in
{
  options.myModules.sillytavern = {
    enable = lib.mkEnableOption "SillyTavern container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/sillytavern/sillytavern:latest";
      description = "SillyTavern container image";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Host port for SillyTavern";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/nixos/sillytavern/config";
      description = "Path to config directory";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/nixos/sillytavern/data";
      description = "Path to data directory";
    };

    pluginsDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/nixos/sillytavern/plugins";
      description = "Path to plugins directory";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.sillytavern = {
      Unit = {
        Description = "SillyTavern Container (Rootless)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Restart = "always";
        ExecStartPre = [
          "-${pkgs.podman}/bin/podman stop sillytavern"
          "${pkgs.podman}/bin/podman network create antigravity-net --ignore"
        ];
        ExecStart = ''
          ${pkgs.podman}/bin/podman run --rm --name sillytavern \
            --network=antigravity-net \
            --network-alias=sillytavern \
            --dns=8.8.8.8 \
            -v ${cfg.configDir}:/home/node/app/config \
            -v ${cfg.dataDir}:/home/node/app/data \
            -v ${cfg.pluginsDir}:/home/node/app/plugins \
            -p 127.0.0.1:${toString cfg.port}:8000 \
            ${cfg.image}
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop sillytavern";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
