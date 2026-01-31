{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Define the user and group consistently
  user = "ashie";
  group = "users";
  puid = "1000";
  pgid = "100";

  # Common env vars to avoid repetition
  commonEnv = {
    PUID = puid;
    PGID = pgid;
    TZ = "Europe/Berlin";
  };
in
{
  # 1. Enable Podman (required backend)
  virtualisation = {
    podman = {
      enable = true;
      autoPrune.enable = true;
    };
    oci-containers.backend = "podman";
  };

  # 2. Container Definitions
  virtualisation.oci-containers.containers = {

    # --- VPN Gateway ---
    vpn = {
      image = "docker.io/qmcgaw/gluetun";
      # The VPN manages the ports for the attached containers
      ports = [
        "8080:8080" # qBittorrent WebUI
        "36630:36630" # Torrent Port TCP
        "36630:36630/udp"
        "9696:9696" # Prowlarr
        "8191:8191" # Flaresolverr
      ];
      environmentFiles = [ config.sops.templates."gluetun.env".path ];
      environment = {
        TZ = "Europe/Berlin";
        DOT = "off"; # DNS over TLS off (optional)
        FIREWALL_OUTBOUND_SUBNETS = "10.89.0.0/24"; # Allow access to local docker network
        FIREWALL_VPN_INPUT_PORTS = "36630"; # Allow incoming torrent traffic
      };
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=media" # It joins the bridge so others can talk to it
        "--network-alias=prowlarr" # Allow other containers to reach Prowlarr via VPN
        "--network-alias=flaresolverr" # Allow other containers to reach Flaresolverr via VPN
        "--add-host=sonarr:10.89.0.50" # Allow Prowlarr to reach Sonarr
        "--add-host=radarr:10.89.0.51" # Allow Prowlarr to reach Radarr
      ];
    };

    # --- Torrent Client (Routed via VPN) ---
    torrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      # VITAL: Reuse the VPN container's network stack
      extraOptions = [ "--network=container:vpn" ];
      dependsOn = [ "vpn" ];
      environment = commonEnv // {
        WEBUI_PORT = "8080";
      };
      volumes = [
        "/var/lib/qbittorrent:/config"
        "/data:/data"
      ];
    };

    # --- The Arr Stack ---
    prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest";
      extraOptions = [
        "--network=container:vpn"
      ];
      dependsOn = [ "vpn" ];
      environment = commonEnv;
      volumes = [ "/var/lib/nixarr/prowlarr:/config" ];
    };

    sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      extraOptions = [
        "--network=media"
        "--ip=10.89.0.50"
      ];
      ports = [ "8989:8989" ];
      environment = commonEnv;
      volumes = [
        "/var/lib/nixarr/sonarr:/config"
        "/data:/data"
      ];
    };

    radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      extraOptions = [
        "--network=media"
        "--ip=10.89.0.51"
      ];
      ports = [ "7878:7878" ];
      environment = commonEnv;
      volumes = [
        "/var/lib/nixarr/radarr:/config"
        "/data:/data"
      ];
    };

    # --- Media Server ---
    jellyfin = {
      image = "lscr.io/linuxserver/jellyfin:latest";
      extraOptions = [
        "--network=media"
        "--device=/dev/dri:/dev/dri"
      ];
      ports = [ "8096:8096" ];
      environment = commonEnv;
      volumes = [
        "/var/lib/nixarr/jellyfin:/config"
        "/data:/data"
      ];
    };

    jellyseerr = {
      image = "ghcr.io/fallenbagel/jellyseerr:latest";
      extraOptions = [ "--network=media" ];
      ports = [ "5055:5055" ];
      environment = commonEnv;
      volumes = [ "/var/lib/nixarr/jellyseerr:/app/config" ];
    };

    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest";
      extraOptions = [ "--network=container:vpn" ];
      dependsOn = [ "vpn" ];
      environment = {
        TZ = "Europe/Berlin";
      };
    };
  };

  # 3. Network Setup (Fixed)
  # Ensure the network is created before ANY container starts
  systemd.services.create-media-network = {
    script = ''
      ${pkgs.podman}/bin/podman network exists media || ${pkgs.podman}/bin/podman network create media
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Removed 'User = ashie' -> Networks created by root are visible to root services
    };
  };

  # Ensure containers wait for the network
  systemd.services."podman-vpn".requires = [ "create-media-network.service" ];
  systemd.services."podman-vpn".after = [ "create-media-network.service" ];
  # (Repeat for others if they don't depend on VPN, but usually unnecessary if they all join 'media')

  # 4. Permissions
  systemd.tmpfiles.rules = [
    "d /data 0775 ${user} media - -"
    "d /var/lib/nixarr/prowlarr 0755 ${user} ${group} - -"
    "d /var/lib/nixarr/sonarr 0755 ${user} ${group} - -"
    "d /var/lib/nixarr/radarr 0755 ${user} ${group} - -"
    "d /var/lib/nixarr/jellyfin 0755 ${user} ${group} - -"
    "d /var/lib/nixarr/jellyseerr 0755 ${user} ${group} - -"
    "d /var/lib/qbittorrent 0755 ${user} ${group} - -"
  ];

  users.users.${user}.extraGroups = [ "media" ];

  # 5. Firewall
  networking.firewall.allowedTCPPorts = [
    80
    443
    9696
    8989
    7878
    8096
    5055
    8080
    36630
    8082
    8191
  ];
  networking.firewall.allowedUDPPorts = [
    36630
    443
  ];
}
