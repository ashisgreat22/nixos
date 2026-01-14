# qBittorrent VPN Module (Home Manager)
# Provides: qBittorrent running through Gluetun VPN as user service
#
# Usage:
#   myModules.qbittorrentVpn = {
#     enable = true;
#     configDir = "/home/user/qbittorrent/config";
#     downloadsDir = "/home/user/qbittorrent/downloads";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.qbittorrentVpn;
in
{
  options.myModules.qbittorrentVpn = {
    enable = lib.mkEnableOption "qBittorrent via VPN container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "lscr.io/linuxserver/qbittorrent:latest";
      description = "qBittorrent container image";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      description = "Path to qBittorrent config directory";
    };

    downloadsDir = lib.mkOption {
      type = lib.types.str;
      description = "Path to downloads directory";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "WebUI port (inside container)";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Berlin";
      description = "Container timezone";
    };

    vpnContainer = lib.mkOption {
      type = lib.types.str;
      default = "gluetun";
      description = "Name of VPN container to route through";
    };

    vpnService = lib.mkOption {
      type = lib.types.str;
      default = "gluetun.service";
      description = "Systemd service name of VPN container";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.qbittorrent = {
      Unit = {
        Description = "qBittorrent Container (Rootless)";
        After = [ cfg.vpnService ];
        Requires = [ cfg.vpnService ];
      };

      Service = {
        Restart = "always";
        ExecStartPre = "-${pkgs.podman}/bin/podman stop qbittorrent";
        ExecStart = ''
          ${pkgs.podman}/bin/podman run --rm --name qbittorrent \
            --network=container:${cfg.vpnContainer} \
            -e PUID=0 \
            -e PGID=0 \
            -e TZ=${cfg.timezone} \
            -e WEBUI_PORT=${toString cfg.webPort} \
            -v ${cfg.configDir}:/config \
            -v ${cfg.downloadsDir}:/downloads \
            ${cfg.image}
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop qbittorrent";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
