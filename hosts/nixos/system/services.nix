{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.flatpak.enable = false;

  services.snowflake-proxy = {
    enable = false;
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
    enable = false;
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

  # Nginx Configuration
  myModules.nginx.enable = true;

  services.nginx.virtualHosts = {
    "_" = {
      default = true;
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      locations."/".return = "444";
    };
    "search.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; frame-src 'self'; base-uri 'self'; form-action 'self';";
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8888";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };
    };

    "api.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header X-Frame-Options "DENY" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:;";
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8045";
        proxyWebsockets = true;
      };
    };

    "chat.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https: blob:; font-src 'self' data:; connect-src 'self' wss: https:; worker-src 'self' blob:;";
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
      };
    };

    "stream.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      # Basic auth is tricky to port directly without htpasswd file management.
      # Since it was hardcoded in Caddy, we'll note that it needs to be set up properly or omitted if not critical for now.
      # For now, excluding basic_auth to avoid breakage, user can add it back via sops secrets for htpasswd.
      locations."/" = {
        proxyPass = "http://127.0.0.1:3333";
        proxyWebsockets = true;
      };
    };

    "stream-api.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Access-Control-Allow-Origin "https://stream.ashisgreat.xyz";
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:3334";
        proxyWebsockets = true;
      };
    };

    "auth.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:9099";
        proxyWebsockets = true;
      };
    };

    "sonarr.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8989";
        proxyWebsockets = true;
      };
    };

    "radarr.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:7878";
        proxyWebsockets = true;
      };
    };

    "prowlarr.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:9696";
        proxyWebsockets = true;
      };
    };

    "torrent.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
      };
    };

    "jellyfin.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src https: data: blob:; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/accentlist.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/base.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/bottombarprogress.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/fixes.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/jf_font.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/overlayprogress.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/rounding.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/rounding_circlehover.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/smallercast.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/rounding_circlehover.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/cornerindicator/indicator_floating.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/cornerindicator/indicator_corner.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/effects/glassy.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/effects/pan-animation.css https://ctalvio.github.io/Monochromic/backdrop-hack_style.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/effects/hoverglow.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/effects/scrollfade.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/episodelist/episodes_compactlist.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/episodelist/episodes_grid.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/fields/fields_border.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/fields/fields_noborder.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/header/header_transparent.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/header/header_transparent-dashboard.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/login/login_frame.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/login/login_minimalistic.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/login/login_frame.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/presets/monochromic_preset.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/presets/kaleidochromic_preset.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/presets/novachromic_preset.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/titlepage/title_banner.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/titlepage/title_banner-logo.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/titlepage/title_simple.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/titlepage/title_simple-logo.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/type/light.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/type/dark.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/type/colorful.css https://cdn.jsdelivr.net/gh/CTalvio/Ultrachromic/type/dark_withaccent.css https://fonts.googleapis.com/css2; script-src 'self' 'unsafe-inline' https://www.gstatic.com/cv/js/sender/v1/cast_sender.js worker-src 'self' blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'self'";
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
        proxyWebsockets = true;
      };
    };

    "jellyseer.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:5055";
        proxyWebsockets = true;
      };
    };

    # Redirect typo domain
    "jellyseerr.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      globalRedirect = "jellyseer.ashisgreat.xyz";
    };

    "reddit.ashisgreat.xyz" = {
      useACMEHost = "ashisgreat.xyz";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8082";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $host;
        '';
      };
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
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
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
