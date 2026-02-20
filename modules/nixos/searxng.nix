# SearXNG Module (Rootless Podman)
# Provides: Private meta-search engine running in a rootless container
#
# Usage:
#   myModules.searxng = {
#     enable = true;
#     port = 8888;
#     domain = "search.ashisgreat.xyz";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.searxng;
  mainUser = config.myModules.system.mainUser;
  mainUserUid = toString config.users.users.${mainUser}.uid;
  anubisPolicy = pkgs.writeText "anubis-policy.yml" ''
    bots:
      - name: "Allow OpenSearch"
        action: ALLOW
        path_regex: ".*opensearch\\.xml.*"
      - name: "Catch-All"
        user_agent_regex: ".*"
        action: CHALLENGE
  '';

  faviconsConfig = pkgs.writeText "favicons.toml" ''
    [favicons]
    cfg_schema = 1

    [favicons.cache]
    db_url = "/var/cache/searxng/faviconcache.db"
    LIMIT_TOTAL_BYTES = 2147483648

    [favicons.proxy.resolver_map]
    google = "searx.favicons.resolver.google_resolver"
    duckduckgo = "searx.favicons.resolver.duckduckgo_resolver"
  '';
in
{
  options.myModules.searxng = {
    enable = lib.mkEnableOption "SearXNG meta-search engine";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Port to expose SearXNG on localhost";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "search.ashisgreat.xyz";
      description = "Public domain name for SearXNG";
    };

    donations = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map of donation platform names to URLs (e.g. { patreon = '...'; })";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure Podman is enabled
    myModules.podman.enable = true;

    # ... (rest of config) ...

    # 1. Create Bridge Network
    systemd.services."create-searxng-network" = {
      serviceConfig.Type = "oneshot";
      serviceConfig.User = mainUser;
      serviceConfig.RemainAfterExit = true;
      after = [ "user-runtime-dir@${mainUserUid}.service" ];
      requires = [ "user-runtime-dir@${mainUserUid}.service" ];
      path = [
        pkgs.podman
        pkgs.shadow
      ];
      script = ''
        export PATH=/run/wrappers/bin:$PATH
        export XDG_RUNTIME_DIR="/run/user/${mainUserUid}"
        export HOME="/home/${mainUser}"
        
        if ! podman network exists searxng-net; then
          echo "Creating searxng-net..."
          podman network create searxng-net --subnet 10.89.2.0/24
        else
          echo "searxng-net already exists."
        fi
      '';
    };

    # 2. Valkey Container (Cache/Limiter)
    virtualisation.oci-containers.containers."searxng-valkey" = {
      image = "docker.io/valkey/valkey:alpine";
      labels = { "io.containers.autoupdate" = "registry"; };
      cmd = [
        "valkey-server"
        "--save"
        ""
        "--appendonly"
        "no"
      ]; # Ephemeral cache, no persistence needed
      extraOptions = [
        "--network=searxng-net"
        "--network-alias=valkey"
      ];
      # No ports published to host for security
    };

    # 3. SearXNG Container
    virtualisation.oci-containers.containers."searxng" = {
      image = "localhost/aadniz/searxng:latest";
      environment = {
        "SEARXNG_BASE_URL" = "https://${cfg.domain}";
        "SEARXNG_REDIS_URL" = "valkey://valkey:6379"; # Talk to Valkey via alias
        "SEARXNG_URL_BASE" = "https://${cfg.domain}";
        "GRANIAN_HOST" = "0.0.0.0";
      };
      environmentFiles = [
        # Contains SEARXNG_SECRET_KEY
        config.sops.templates."searxng.env".path
      ];
      extraOptions = [
        "--network=searxng-net"
        "--network-alias=searxng"
        "--cap-drop=ALL"
        "--cap-add=CHOWN"
        "--cap-add=SETGID"
        "--cap-add=SETUID"
        "--cap-add=DAC_OVERRIDE"
      ];
      volumes = [
        "${config.sops.templates."searxng_settings.yml".path}:/etc/searxng/settings.yml:ro"

        "${faviconsConfig}:/etc/searxng/favicons.toml:ro"
        "${./braveapi.py}:/usr/local/searxng/searx/engines/braveapi.py:ro"
        "searxng-cache:/var/cache/searxng"
      ];
      dependsOn = [ "searxng-valkey" ];
    };

    # 4. Anubis Container (AI Firewall)
    virtualisation.oci-containers.containers."searxng-anubis" = {
      image = "ghcr.io/techarohq/anubis:latest";
      labels = { "io.containers.autoupdate" = "registry"; };
      ports = [ "127.0.0.1:${toString cfg.port}:8080" ];
      environment = {
        "TARGET" = "http://searxng:8080";
        "BIND" = ":8080";
        "POLICY_FNAME" = "/etc/anubis/policy.yml";
      };
      extraOptions = [
        "--network=searxng-net"
        "--network-alias=searxng-anubis"
      ];
      volumes = [
        "${anubisPolicy}:/etc/anubis/policy.yml:ro"
      ];
      dependsOn = [ "searxng" ];
    };

    sops.templates."searxng.env" = {
      owner = mainUser;
      content = ''
        SEARXNG_SECRET_KEY=${config.sops.placeholder.searxng_secret_key}
        BRAVE_API_KEY=${config.sops.placeholder.searxng_brave_api_key}
      '';
    };

    sops.templates."searxng_settings.yml" = {
      owner = mainUser;
      content = ''
        use_default_settings: true

        general:
          debug: false
          instance_name: "Ashie Search"
          contact_url: false
          issue_url: false
          donation_url: ${if cfg.donations ? "Monero" then "\"${cfg.donations.Monero}\"" else "false"}
          donations:
            ${lib.concatStringsSep "\n            " (
              lib.mapAttrsToList (name: url: "${name}: \"${url}\"") cfg.donations
            )}

        engines:
          - name: braveapi
            engine: braveapi
            shortcut: brapi
            categories: general
            # api_key: set via BRAVE_API_KEY env var
            tokens: ["${config.sops.placeholder.searxng_private_token}"]
            timeout: 2.0
            weight: 2
            disabled: false


        search:
          safe_search: 0
          favicon_resolver: "google"
          autocomplete: "google"
          default_lang: "en-US"
          formats:
            - html
            - json

        server:
          port: 8080
          bind_address: "0.0.0.0"
          secret_key: "${config.sops.placeholder.searxng_secret_key}"
          limiter: true
          image_proxy: true
          public_instance: true

        default_http_headers:
          Content-Security-Policy: "upgrade-insecure-requests; default-src 'none'; script-src 'self'; style-src 'self' 'sha256-/ldGxQqxNIMRftg3AGsPF+F281wiBPECUDcL2RJkxdU='; form-action 'self' https://github.com/searxng/searxng/issues/new; font-src 'self'; frame-ancestors 'self'; img-src 'self' data:; connect-src 'self' https://overpass-api.de; manifest-src 'self'"

        ui:
          default_theme: red-floof
          default_theme_style: dark
          static_use_hash: true

        redis:
          url: valkey://valkey:6379/0
      '';
    };

    # Secret definitions
    sops.secrets.searxng_secret_key = { };
    sops.secrets.searxng_brave_api_key = { };
    sops.secrets.searxng_private_token = { };

    # Rootless Overrides
    systemd.services."podman-searxng".serviceConfig.User = lib.mkForce mainUser;
    systemd.services."podman-searxng".environment = {
      HOME = "/home/${mainUser}";
      XDG_RUNTIME_DIR = "/run/user/${mainUserUid}";
    };
    systemd.services."podman-searxng".serviceConfig.Type = lib.mkForce "simple";
    systemd.services."podman-searxng".serviceConfig.Delegate = true;
    systemd.services."podman-searxng".after = [
      "create-searxng-network.service"
      "user-runtime-dir@${mainUserUid}.service"
      "network-online.target"
    ];
    systemd.services."podman-searxng".requires = [
      "create-searxng-network.service"
      "user-runtime-dir@${mainUserUid}.service"
      "network-online.target"
    ];

    systemd.services."podman-searxng-valkey".serviceConfig.User = lib.mkForce mainUser;
    systemd.services."podman-searxng-valkey".environment = {
      HOME = "/home/${mainUser}";
      XDG_RUNTIME_DIR = "/run/user/${mainUserUid}";
    };
    systemd.services."podman-searxng-valkey".serviceConfig.Type = lib.mkForce "simple";
    systemd.services."podman-searxng-valkey".serviceConfig.Delegate = true;
    systemd.services."podman-searxng-valkey".after = [
      "create-searxng-network.service"
      "user-runtime-dir@${mainUserUid}.service"
      "network-online.target"
    ];
    systemd.services."podman-searxng-valkey".requires = [
      "create-searxng-network.service"
      "user-runtime-dir@${mainUserUid}.service"
      "network-online.target"
    ];

    systemd.services."podman-searxng-anubis".serviceConfig.User = lib.mkForce mainUser;
    systemd.services."podman-searxng-anubis".environment = {
      HOME = "/home/${mainUser}";
      XDG_RUNTIME_DIR = "/run/user/${mainUserUid}";
    };
    systemd.services."podman-searxng-anubis".serviceConfig.Type = lib.mkForce "simple";
    systemd.services."podman-searxng-anubis".serviceConfig.Delegate = true;
    systemd.services."podman-searxng-anubis".after = [
      "create-searxng-network.service"
      "user-runtime-dir@${mainUserUid}.service"
      "network-online.target"
    ];
    systemd.services."podman-searxng-anubis".requires = [
      "create-searxng-network.service"
      "user-runtime-dir@${mainUserUid}.service"
      "network-online.target"
    ];

  };
}
