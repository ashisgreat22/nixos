{
  config,
  lib,
  pkgs,
  ...
}:

{

  # Nixarr Configuration
  # Replaces OCI containers with native NixOS services
  # Nixflix Configuration
  nixflix = {
    enable = false; # Disabled to revert to Podman
    stateDir = "/var/lib/nixflix";
    mediaDir = "/data";

    sonarr.enable = false;
    radarr.enable = false;
    prowlarr.enable = false;
    jellyfin.enable = false;
    jellyseerr.enable = false;

    # We use external OCI containers for these
    sabnzbd.enable = false;
    mullvad.enable = false;

    # Jellyseerr defaults to VPN=true, but we disabled Mullvad, so we must disable VPN here too.
    jellyseerr.vpn.enable = false;
  };

  # Homepage Dashboard
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;

    # Custom settings for better visual appearance
    settings = {
      title = "Media Dashboard";
      theme = "dark";
      color = "slate";
      headerStyle = "boxed";
      layout = {
        "Media" = {
          style = "row";
          columns = 2;
        };
        "Automation" = {
          style = "row";
          columns = 3;
        };
        "Downloads" = {
          style = "row";
          columns = 2;
        };
      };
    };

    services = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              icon = "jellyfin.png";
              href = "http://localhost:8096";
              description = "Media Server";
              widget = {
                type = "jellyfin";
                url = "http://localhost:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
                enableBlocks = true;
                enableNowPlaying = true;
              };
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr.png";
              href = "http://localhost:5055";
              description = "Media Requests";
              widget = {
                type = "jellyseerr";
                url = "http://localhost:5055";
                key = "{{HOMEPAGE_VAR_JELLYSEERR_API_KEY}}";
              };
            };
          }
        ];
      }

      {
        "Automation" = [
          {
            "Sonarr" = {
              icon = "sonarr.png";
              href = "http://localhost:8989";
              description = "TV Series";
              widget = {
                type = "sonarr";
                url = "http://localhost:8989";
                key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            "Radarr" = {
              icon = "radarr.png";
              href = "http://localhost:7878";
              description = "Movies";
              widget = {
                type = "radarr";
                url = "http://localhost:7878";
                key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
                enableQueue = true;
              };
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr.png";
              href = "http://localhost:9696";
              description = "Indexer Manager";
              widget = {
                type = "prowlarr";
                url = "http://localhost:9696";
                key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
              };
            };
          }
        ];
      }
      {
        "Downloads" = [
          {
            "qBittorrent" = {
              icon = "qbittorrent.png";
              href = "http://localhost:8080";
              description = "Torrent Client";
              widget = {
                type = "qbittorrent";
                url = "http://localhost:8080";
                username = "{{HOMEPAGE_VAR_QBITTORRENT_USERNAME}}";
                password = "{{HOMEPAGE_VAR_QBITTORRENT_PASSWORD}}";
              };
            };
          }
        ];
      }
    ];

    bookmarks = [
      {
        "Dev" = [
          {
            "GitHub" = [
              {
                abbr = "GH";
                href = "https://github.com";
              }
            ];
          }
          {
            "NixOS Search" = [
              {
                abbr = "NO";
                href = "https://search.nixos.org";
              }
            ];
          }
          {
            "Home Manager" = [
              {
                abbr = "HM";
                href = "https://nix-community.github.io/home-manager/options.xhtml";
              }
            ];
          }
        ];
      }
      {
        "Media" = [
          {
            "Trakt" = [
              {
                abbr = "TR";
                href = "https://trakt.tv";
              }
            ];
          }
          {
            "IMDb" = [
              {
                abbr = "IM";
                href = "https://imdb.com";
              }
            ];
          }
        ];
      }
    ];

    widgets = [
      {
        resources = {
          cpu = true;
          disk = "/";
          memory = true;
          uptime = true;
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
      {
        datetime = {
          text_size = "xl";
          format = {
            dateStyle = "long";
            timeStyle = "short";
            hour12 = false;
          };
        };
      }
      {
        openmeteo = {
          label = "Berlin";
          latitude = 52.52;
          longitude = 13.405;
          units = "metric";
          cache = 5;
        };
      }
    ];
  };

  # SOPS Secrets for Homepage
  sops.templates."homepage.env" = {
    content = ''
      HOMEPAGE_VAR_JELLYFIN_API_KEY=
      HOMEPAGE_VAR_JELLYSEERR_API_KEY=
      HOMEPAGE_VAR_SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
      HOMEPAGE_VAR_RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
      HOMEPAGE_VAR_PROWLARR_API_KEY=${config.sops.placeholder.prowlarr_api_key}
      HOMEPAGE_VAR_QBITTORRENT_USERNAME=
      HOMEPAGE_VAR_QBITTORRENT_PASSWORD=
    '';
  };

  # Inject secrets into Homepage service
  systemd.services.homepage-dashboard = {
    serviceConfig = {
      EnvironmentFile = lib.mkForce config.sops.templates."homepage.env".path;
    };
  };

  # OCI Containers for Media Stack
  virtualisation.oci-containers.containers = {
    # VPN (Gluetun)
    vpn = {
      image = "docker.io/qmcgaw/gluetun";
      ports = [
        "8080:8080" # qBittorrent WebUI
        "36630:36630" # Torrent Port TCP
        "36630:36630/udp" # Torrent Port UDP
      ];
      environmentFiles = [ config.sops.templates."gluetun.env".path ];
      environment = {
        TZ = "Europe/Berlin";
        DOT = "off";
        # DNS_ADDRESS = "1.1.1.1";
        WIREGUARD_MTU = "1420";
        # Allow access to local Podman network (for Prowlarr/Jellyseerr)
        FIREWALL_OUTBOUND_SUBNETS = "10.88.0.0/16";
      };
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--device=/dev/net/tun:/dev/net/tun"
        "--network=media" # Join the shared media network
      ];
    };

    # qBittorrent (Networked via VPN)
    torrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      extraOptions = [ "--network=container:vpn" ];
      dependsOn = [ "vpn" ];
      environment = {
        PUID = "1000"; # ashie
        PGID = "100"; # users
        TZ = "Europe/Berlin";
        WEBUI_PORT = "8080";
      };
      volumes = [
        "/var/lib/qbittorrent:/config"
        "/data:/data"
      ];
    };

    # Flaresolverr (Direct connection)
    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest";
      extraOptions = [ "--network=media" ];
      ports = [ "8191:8191" ];
      environment = {
        TZ = "Europe/Berlin";
      };
    };

    # Prowlarr (Direct connection)
    prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest";
      extraOptions = [ "--network=media" ];
      ports = [ "9696:9696" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/nixarr/prowlarr:/config"
      ];
    };

    # Sonarr (Direct connection)
    sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      extraOptions = [ "--network=media" ];
      ports = [ "8989:8989" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/nixarr/sonarr:/config"
        "/data:/data"
      ];
    };

    # Radarr (Direct connection)
    radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      extraOptions = [ "--network=media" ];
      ports = [ "7878:7878" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/nixarr/radarr:/config"
        "/data:/data"
      ];
    };

    # Jellyfin (Direct connection)
    jellyfin = {
      image = "lscr.io/linuxserver/jellyfin:latest";
      extraOptions = [ "--network=media" ];
      ports = [ "8096:8096" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/nixarr/jellyfin:/config"
        "/data:/data"
      ];
    };

    # Jellyseerr (Direct connection)
    jellyseerr = {
      image = "ghcr.io/fallenbagel/jellyseerr:latest";
      extraOptions = [ "--network=media" ];
      ports = [ "5055:5055" ];
      environment = {
        PUID = "1000";
        PGID = "100";
        TZ = "Europe/Berlin";
      };
      volumes = [
        "/var/lib/nixarr/jellyseerr:/app/config"
      ];
    };

  };

  # Define the dedicated media network
  systemd.services.create-media-network = {
    script = ''
      ${pkgs.podman}/bin/podman network exists media || ${pkgs.podman}/bin/podman network create media
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "ashie";
    };
  };

  # Ensure the /data directory exists (Nixarr uses it)
  systemd.tmpfiles.rules = [
    # Data directory: owned by ashie:media so both qBittorrent (ashie) and others can access
    "d /data 0775 ashie media - -"

    # Ensure config directories exist with correct permissions
    "d /var/lib/nixarr/prowlarr 0755 ashie users - -"
    "d /var/lib/nixarr/sonarr 0755 ashie users - -"
    "d /var/lib/nixarr/radarr 0755 ashie users - -"
    "d /var/lib/nixarr/jellyfin 0755 ashie users - -"
    "d /var/lib/nixarr/jellyseerr 0755 ashie users - -"

    # qBittorrent directory
    "d /var/lib/qbittorrent 0755 ashie users - -"

  ];

  # Add ashie to media group to ensure access to /data
  users.users.ashie.extraGroups = [ "media" ];

  # Firewall rules
  networking.firewall.allowedTCPPorts = [
    80 # HTTP
    443 # HTTPS
    9696 # Prowlarr
    8989 # Sonarr
    7878 # Radarr
    8096 # Jellyfin
    5055 # Jellyseerr
    8080 # qBittorrent WebUI
    36630 # Torrent

    8082 # Homepage

  ];
  networking.firewall.allowedUDPPorts = [
    36630
    443
  ];

  # Rootless Container Overrides
  # Force these containers to run as user 'ashie'
  systemd.services."podman-vpn".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-vpn".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-vpn".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-vpn".serviceConfig.Delegate = true;

  systemd.services."podman-torrent".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-torrent".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-torrent".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-torrent".serviceConfig.Delegate = true;

  systemd.services."podman-flaresolverr".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-flaresolverr".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-flaresolverr".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-flaresolverr".serviceConfig.Delegate = true;

  systemd.services."podman-prowlarr".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-prowlarr".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-prowlarr".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-prowlarr".serviceConfig.Delegate = true;

  systemd.services."podman-sonarr".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-sonarr".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-sonarr".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-sonarr".serviceConfig.Delegate = true;

  systemd.services."podman-radarr".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-radarr".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-radarr".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-radarr".serviceConfig.Delegate = true;

  systemd.services."podman-jellyfin".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-jellyfin".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-jellyfin".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-jellyfin".serviceConfig.Delegate = true;

  systemd.services."podman-jellyseerr".serviceConfig.User = lib.mkForce "ashie";
  systemd.services."podman-jellyseerr".environment = {
    HOME = "/home/ashie";
    XDG_RUNTIME_DIR = "/run/user/1000";
  };
  systemd.services."podman-jellyseerr".serviceConfig.Type = lib.mkForce "simple";
  systemd.services."podman-jellyseerr".serviceConfig.Delegate = true;
}
