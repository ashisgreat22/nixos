{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.flatpak.enable = false;

  services.snowflake-proxy = {
    enable = true;
    capacity = 10;
  };

  services.timesyncd.enable = false;
  services.chrony = {
    enable = true;
    enableNTS = true;
    servers = [
      "time.cloudflare.com"
      "nts.netnod.se"
      "ptbtime1.ptb.de"
    ];
    extraConfig = ''
      user chrony
      pidfile /run/chrony/chrony.pid
      driftfile /var/lib/chrony/drift
      makestep 1.0 3
    '';
  };

  services.fstrim.enable = true;

  services.dbus.implementation = "broker";

  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    freeMemThreshold = 5;
  };

  services.openssh = {
    enable = true;
    ports = [ 5732 ];
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowAgentForwarding = false;
      UseDns = false;
    };
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.firefox.enable = false;

  services.caddy = {
    enable = true;
    email = "mails@ashisgreat.xyz";

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.3-0.20251204174556-6dc1fbb7e925" ];
      hash = "sha256-htrfa7whiIK2pqtKl6pKFby928dCkMmJp3Hu0e3JBX4=";
    };
    globalConfig = ''
      acme_dns cloudflare {env.CF_API_TOKEN}
      servers {
        protocols h1 h2 h3
      }
    '';

    extraConfig = ''
      (security_headers) {
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          Referrer-Policy "strict-origin-when-cross-origin"
          X-XSS-Protection "1; mode=block"
          Permissions-Policy "camera=(), microphone=(), geolocation=(), interest-cohort=()"
          -Server
        }
      }
    '';

    virtualHosts."search.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:8888
      '';
    };

    virtualHosts."api.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        header {
          X-Frame-Options "DENY"
          Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:;"
        }
        reverse_proxy 127.0.0.1:8045
      '';
    };

    virtualHosts."chat.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        header {
          Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https: blob:; font-src 'self' data:; connect-src 'self' wss: https:; worker-src 'self' blob:;"
        }
        reverse_proxy 127.0.0.1:3000
      '';
    };

    virtualHosts."stream.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        basic_auth {
            admin $2a$14$2kaAS6oLx6SdyuM2lksnYOZidfRWb7AGPXT5hhg/s5nseL7bjHsx2
        }
        reverse_proxy 127.0.0.1:3333
      '';
    };

    virtualHosts."stream-api.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        header {
          Access-Control-Allow-Origin "https://stream.ashisgreat.xyz"
        }
        reverse_proxy 127.0.0.1:3334
      '';
    };

    virtualHosts."sonarr.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:8989
      '';
    };

    virtualHosts."radarr.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:7878
      '';
    };

    virtualHosts."prowlarr.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:9696
      '';
    };

    virtualHosts."torrent.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:8080
      '';
    };

    virtualHosts."jellyfin.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:8096
      '';
    };

    virtualHosts."jellyseer.ashisgreat.xyz" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:5055
      '';
    };

    virtualHosts."jellyseerr.ashisgreat.xyz" = {
      extraConfig = ''
        redir https://jellyseer.ashisgreat.xyz{uri}
      '';
    };

  };

  # Hardening for Chrony
  systemd.services.chronyd.serviceConfig = {
    ProtectSystem = lib.mkForce "strict";
    ProtectHome = true;
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    # Chrony needs to adjust time, preserve CAP_SYS_TIME and CAP_NET_BIND_SERVICE
    CapabilityBoundingSet = [
      "CAP_SYS_TIME"
      "CAP_NET_BIND_SERVICE"
    ];
    MemoryDenyWriteExecute = true;
    LockPersonality = true;
  };

  # Hardening for EarlyOOM
  systemd.services.earlyoom.serviceConfig = {
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    MemoryDenyWriteExecute = true;
    LockPersonality = true;
  };

  systemd.services.caddy.serviceConfig = {
    NoNewPrivileges = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy.env".path;

  # Hardening for Snowflake Proxy
  systemd.services.snowflake-proxy.serviceConfig = {
    DynamicUser = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    MemoryDenyWriteExecute = true;
    LockPersonality = true;
    RestrictRealtime = true;
    SystemCallFilter = [ "@system-service" "~@privileged" ];
  };

  # Hardening for DDClient
  systemd.services.ddclient.serviceConfig = {
    ProtectSystem = "full";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    ReadWritePaths = [ "/run/ddclient" ];
    NoNewPrivileges = true;
  };
}
