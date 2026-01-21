# Unified Router Module (Home Manager)
# Provides: Unified API router as rootless container
#
# Usage:
#   myModules.unifiedRouter = {
#     enable = true;
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.unifiedRouter;
in
{
  options.myModules.unifiedRouter = {
    enable = lib.mkEnableOption "Unified API Router";

    image = lib.mkOption {
      type = lib.types.str;
      default = "localhost/unified-router:latest";
      description = "Unified Router container image";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "Host port for Unified Router";
    };
    environmentFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/rendered/api_key.env";
      description = "Path to environment file containing API_KEY";
    };
    antigravityPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/nixos/antigravity-src";
      description = "Path to antigravity-src directory";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/.local/share/unified-router";
      description = "Path to persist container data (accounts.json, etc.)";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.unified-router = {
      Unit = {
        Description = "Unified API Router Container (Rootless)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Environment = "PATH=/run/wrappers/bin:/run/current-system/sw/bin";
        Restart = "always";
        RestartSec = "10s";
        ExecStartPre = [
          # Best effort cleanup, ignore errors
          "-${pkgs.podman}/bin/podman system migrate"
          "-${pkgs.podman}/bin/podman rm -f unified-router --ignore"
          "-${pkgs.podman}/bin/podman stop unified-router --ignore"
          # Network creation removed (host mode)
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}"
        ];
        ExecStart = ''
          ${pkgs.podman}/bin/podman run --replace --rm --name unified-router \
            --user 0 \
            --network=host \
            -e PORT=${toString cfg.port} \
            --env-file=${cfg.environmentFile} \
            -e LOG_LEVEL=debug \
            -v ${cfg.dataDir}:/app/data \
            ${cfg.image}
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop -t 10 unified-router";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
