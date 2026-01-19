{
  config,
  lib,
  pkgs,
  ...
}:

{
  # 1. Create the 'media' group (optional now if running as user)
  users.groups.media = { };

  # 2. OCI Container Configuration
  virtualisation.oci-containers.containers = {
    # Prowlarr
    prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest";
      ports = [ "9696:9696" ];
      environment = {
        PUID = "1000";
        PGID = "100"; # users group
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/prowlarr:/config"
      ];
    };

    # Sonarr
    sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      ports = [ "8989:8989" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/sonarr:/config"
        "/data:/data"
      ];
    };

    # Radarr
    radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      ports = [ "7878:7878" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/radarr:/config"
        "/data:/data"
      ];
    };
    # FlareSolverr (Cloudflare Bypass)
    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest";
      ports = [ "8191:8191" ];
      environment = {
        TZ = "Europe/Berlin";
        LOG_LEVEL = "info";
      };
    };

    # Jellyfin (Media Server)
    jellyfin = {
      image = "lscr.io/linuxserver/jellyfin:latest";
      ports = [ "8096:8096" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/jellyfin:/config"
        "/data:/data"
      ];
    };

    # VPN (Gluetun)
    # WARNING: You must configure your VPN provider details in 'environmentFiles' or 'environment'
    vpn = {
      image = "qmcgaw/gluetun";
      ports = [
        "8080:8080" # qBittorrent WebUI
        "6881:6881" # Torrent Port TCP
        "6881:6881/udp" # Torrent Port UDP
      ];
      environmentFiles = [ config.sops.templates."gluetun.env".path ];
      environment = {
        TZ = "Europe/Berlin";
        DOT = "off";
        DNS_ADDRESS = "1.1.1.1";
        WIREGUARD_MTU = "1420";
      };
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--device=/dev/net/tun:/dev/net/tun"
      ];
    };

    # qBittorrent (Networked via VPN)
    torrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      # Ports are exposed via vpn container, not here
      extraOptions = [ "--network=container:vpn" ];
      dependsOn = [ "vpn" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
        WEBUI_PORT = "8080";
      };
      volumes = [
        "/var/lib/qbittorrent:/config"
        "/data:/data"
      ];
    };

    # Jellyseerr (Request Management)
    jellyseerr = {
      image = "docker.io/fallenbagel/jellyseerr:latest";
      ports = [ "5055:5055" ];
      environment = {
        LOG_LEVEL = "debug";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/jellyseerr:/app/config"
      ];
    };
  };

  # Ensure config directories exist and are owned by the user (1000)
  systemd.tmpfiles.rules = [
    "d /data 0755 ashie users - -"
    "d /var/lib/prowlarr 0755 ashie users - -"
    "d /var/lib/sonarr 0755 ashie users - -"
    "d /var/lib/radarr 0755 ashie users - -"
    "d /var/lib/qbittorrent 0755 ashie users - -"
    "d /var/lib/jellyfin 0755 ashie users - -"
    "d /var/lib/jellyseerr 0755 ashie users - -"
    # Recursively fix permissions on restart to ensure 1000 owns the config
    "Z /var/lib/prowlarr - ashie users - -"
    "Z /var/lib/sonarr - ashie users - -"
    "Z /var/lib/radarr - ashie users - -"
    "Z /var/lib/qbittorrent - ashie users - -"
    "Z /var/lib/jellyfin - ashie users - -"
    "Z /var/lib/jellyseerr - ashie users - -"
  ];

  # Firewall rules
  networking.firewall.allowedTCPPorts = [
    9696
    8989
    7878
    8191
    8080
    8096
    5055
    6881
  ];
  networking.firewall.allowedUDPPorts = [ 6881 ];
}
