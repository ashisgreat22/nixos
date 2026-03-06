{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.media;
  user = config.myModules.system.mainUser;
  group = "users";
  puid = toString config.users.users.${user}.uid;
  pgid = "100"; # GID for 'users' group

  # Common env vars to avoid repetition
  commonEnv = {
    PUID = puid;
    PGID = pgid;
    TZ = "Europe/Berlin";
  };

  # Host aliases so containers can communicate using public domain names locally (routes traffic to Nginx)
  localAddHosts = [
    "--add-host=sonarr.ashisgreat.xyz:10.89.0.1"
    "--add-host=radarr.ashisgreat.xyz:10.89.0.1"
    "--add-host=prowlarr.ashisgreat.xyz:10.89.0.1"
    "--add-host=torrent.ashisgreat.xyz:10.89.0.1"
    "--add-host=jellyfin.ashisgreat.xyz:10.89.0.1"
    "--add-host=jellyseer.ashisgreat.xyz:10.89.0.1"
    "--add-host=auth.ashisgreat.xyz:10.89.0.1"
  ];
in
{
  options.myModules.media = {
    enable = lib.mkEnableOption "media server stack (Arr suite + Jellyfin)";
  };

  config = lib.mkIf cfg.enable {
    # 1. Enable Podman (required backend)
    myModules.podman.enable = true;
    virtualisation.podman.autoPrune.enable = true;

    # 2. Container Definitions
    virtualisation.oci-containers.containers = {

      # --- VPN Gateway ---
      vpn = {
        image = "docker.io/qmcgaw/gluetun:v3.41.1"; # Pinned: v3.42+ breaks on kernels without nfnetlink_conntrack (conntrack flush via netlink fails)
        # No auto-update label — pinned to specific version intentionally
        # The VPN manages the ports for the attached containers
        ports = [
          "127.0.0.1:8080:8080" # qBittorrent WebUI (Localhost only)
          "36630:36630" # Torrent Port TCP (Public)
          "36630:36630/udp" # Torrent Port UDP (Public)
          "127.0.0.1:8191:8191" # Flaresolverr (Localhost only)
          "127.0.0.1:9696:9696" # Prowlarr (Localhost only)
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
          "--ip=10.89.0.5" # Static IP for VPN/Flaresolverr
          "--network-alias=flaresolverr" # Allow other containers to reach Flaresolverr via VPN
        ]
        ++ localAddHosts;
      };

      # --- Torrent Client (Routed via VPN) ---
      torrent = {
        image = "lscr.io/linuxserver/qbittorrent:latest";
        labels = {
          "io.containers.autoupdate" = "registry";
        };
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
        labels = {
          "io.containers.autoupdate" = "registry";
        };
        extraOptions = [
          "--network=container:vpn"
        ];
        dependsOn = [ "vpn" ];
        environment = commonEnv;
        volumes = [ "/var/lib/nixarr/prowlarr:/config" ];
      };

      sonarr = {
        image = "lscr.io/linuxserver/sonarr:latest";
        labels = {
          "io.containers.autoupdate" = "registry";
        };
        extraOptions = [
          "--network=media"
          "--ip=10.89.0.50"
          "--dns=8.8.8.8"
        ]
        ++ localAddHosts;
        ports = [ "127.0.0.1:8989:8989" ];
        environment = commonEnv;
        volumes = [
          "/var/lib/nixarr/sonarr:/config"
          "/data:/data"
        ];
      };

      radarr = {
        image = "lscr.io/linuxserver/radarr:latest";
        labels = {
          "io.containers.autoupdate" = "registry";
        };
        extraOptions = [
          "--network=media"
          "--ip=10.89.0.51"
          "--dns=8.8.8.8"
        ]
        ++ localAddHosts;
        ports = [ "127.0.0.1:7878:7878" ];
        environment = commonEnv;
        volumes = [
          "/var/lib/nixarr/radarr:/config"
          "/data:/data"
        ];
      };

      # --- Media Server ---
      jellyfin = {
        image = "lscr.io/linuxserver/jellyfin:latest";
        labels = {
          "io.containers.autoupdate" = "registry";
        };
        extraOptions = [
          "--network=media"
          "--device=/dev/dri:/dev/dri"
          "--dns=8.8.8.8"
          "--ip=10.89.0.4"
        ]
        ++ localAddHosts;
        ports = [ "127.0.0.1:8096:8096" ];
        environment = commonEnv;
        volumes = [
          "/var/lib/nixarr/jellyfin:/config"
          "/data:/data"
        ];
      };

      jellyseerr = {
        image = "ghcr.io/seerr-team/seerr:latest"; # Migrated from jellyseerr (stale) to seerr (v3+)
        labels = {
          "io.containers.autoupdate" = "registry";
        };
        extraOptions = [
          "--init" # Required for Seerr
          "--network=media"
          "--dns=8.8.8.8"
          "--ip=10.89.0.3"
        ]
        ++ localAddHosts;
        ports = [ "127.0.0.1:5055:5055" ];
        environment = commonEnv;
        volumes = [ "/var/lib/nixarr/jellyseerr:/app/config" ];
      };

      flaresolverr = {
        image = "ghcr.io/flaresolverr/flaresolverr:latest";
        labels = {
          "io.containers.autoupdate" = "registry";
        };
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
        ${pkgs.podman}/bin/podman network exists media || ${pkgs.podman}/bin/podman network create --subnet 10.89.0.0/24 media
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
      "d /data 0775 ${user} ${group} - -"
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
      36630
      9696
    ];
    networking.firewall.allowedUDPPorts = [
      36630
      443
    ];
  };
}
