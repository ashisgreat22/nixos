{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.caddyCloudflare;

  # Generate virtual host configs with security headers
  mkVirtualHost = name: hostCfg: {
    extraConfig = ''
      # Security headers
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "${hostCfg.frameOptions}"
        Referrer-Policy "strict-origin-when-cross-origin"
        ${lib.optionalString (hostCfg.csp != null) ''Content-Security-Policy "${hostCfg.csp}"''}
        -Server
      }
      reverse_proxy ${hostCfg.reverseProxy}
    '';
  };
in
{
  options.myModules.caddyCloudflare = {
    enable = lib.mkEnableOption "Caddy with Cloudflare DNS-01 ACME";

    email = lib.mkOption {
      type = lib.types.str;
      description = "Email for ACME certificate registration";
    };

    cloudflareApiTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing Cloudflare API token";
    };

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            reverseProxy = lib.mkOption {
              type = lib.types.str;
              description = "Backend address (e.g., 127.0.0.1:8080)";
            };
            frameOptions = lib.mkOption {
              type = lib.types.str;
              default = "DENY";
              description = "X-Frame-Options header value";
            };
            csp = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:;";
              description = "Content-Security-Policy header (null to disable)";
            };
          };
        }
      );
      default = { };
      description = "Virtual host configurations";
    };

    hardenSystemd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply systemd hardening to Caddy service";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      email = cfg.email;

      # Caddy with Cloudflare DNS plugin
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.3-0.20251204174556-6dc1fbb7e925" ];
        hash = "sha256-htrfa7whiIK2pqtKl6pKFby928dCkMmJp3Hu0e3JBX4=";
      };

      globalConfig = ''
        acme_dns cloudflare {env.CF_API_TOKEN}
        servers {
          protocols h1 h2
        }
      '';

      virtualHosts = lib.mapAttrs mkVirtualHost cfg.virtualHosts;
    };

    # Systemd hardening
    systemd.services.caddy.serviceConfig = lib.mkIf cfg.hardenSystemd {
      NoNewPrivileges = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      EnvironmentFile = cfg.cloudflareApiTokenFile;
    };
  };
}
