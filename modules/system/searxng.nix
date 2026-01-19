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

  catppuccinCss = pkgs.writeText "searxng-catppuccin.css" ''
    :root {
        /* Mocha (Dark) */
        --cat-rosewater: #f5e0dc;
        --cat-flamingo: #f2cdcd;
        --cat-pink: #f5c2e7;
        --cat-mauve: #cba6f7;
        --cat-red: #f38ba8;
        --cat-maroon: #eba0ac;
        --cat-peach: #fab387;
        --cat-yellow: #f9e2af;
        --cat-green: #a6e3a1;
        --cat-teal: #94e2d5;
        --cat-sky: #89dceb;
        --cat-sapphire: #74c7ec;
        --cat-blue: #89b4fa;
        --cat-lavender: #b4befe;
        --cat-text: #cdd6f4;
        --cat-subtext1: #bac2de;
        --cat-subtext0: #a6adc8;
        --cat-overlay2: #9399b2;
        --cat-overlay1: #7f849c;
        --cat-overlay0: #6c7086;
        --cat-surface2: #585b70;
        --cat-surface1: #45475a;
        --cat-surface0: #313244;
        --cat-base: #1e1e2e;
        --cat-mantle: #181825;
        --cat-crust: #11111b;
    }

    @media (prefers-color-scheme: light) {
        :root {
            /* Latte (Light) */
            --cat-rosewater: #dc8a78;
            --cat-flamingo: #dd7878;
            --cat-pink: #ea76cb;
            --cat-mauve: #8839ef;
            --cat-red: #d20f39;
            --cat-maroon: #e64553;
            --cat-peach: #fe640b;
            --cat-yellow: #df8e1d;
            --cat-green: #40a02b;
            --cat-teal: #179287;
            --cat-sky: #04a5e5;
            --cat-sapphire: #209fb5;
            --cat-blue: #1e66f5;
            --cat-lavender: #7287fd;
            --cat-text: #4c4f69;
            --cat-subtext1: #5c5f77;
            --cat-subtext0: #6c6f85;
            --cat-overlay2: #7c7f93;
            --cat-overlay1: #8c8fa1;
            --cat-overlay0: #9ca0b0;
            --cat-surface2: #acb0be;
            --cat-surface1: #bcc0cc;
            --cat-surface0: #ccd0da;
            --cat-base: #eff1f5;
            --cat-mantle: #e6e9ef;
            --cat-crust: #dce0e8;
        }
    }

    /* Apply variables */
    :root {
        --color-base-font: var(--cat-text);
        --color-base-background: var(--cat-base);
        --color-base-background-mobile: var(--cat-base);
        --color-url-font: var(--cat-mauve);
        --color-url-visited-font: var(--cat-mauve);
        --color-header-background: var(--cat-mantle);
        --color-header-border: var(--cat-mantle);
        --color-footer-background: var(--cat-mantle);
        --color-footer-border: var(--cat-mantle);
        --color-sidebar-border: var(--cat-base);
        --color-sidebar-font: var(--cat-text);
        --color-sidebar-background: var(--cat-base);
        --color-backtotop-font: var(--cat-subtext1);
        --color-backtotop-border: var(--cat-surface0);
        --color-backtotop-background: var(--cat-surface0);
        --color-btn-background: var(--cat-mauve);
        --color-btn-font: var(--cat-base);
        --color-show-btn-background: var(--cat-mauve);
        --color-show-btn-font: var(--cat-base);
        --color-search-border: var(--cat-surface0);
        --color-search-shadow: 0 2px 8px var(--cat-crust);
        --color-search-background: var(--cat-surface0);
        --color-search-font: var(--cat-text);
        --color-search-background-hover: var(--cat-mauve);
        --color-error: var(--cat-red);
        --color-error-background: var(--cat-surface0);
        --color-warning: var(--cat-yellow);
        --color-warning-background: var(--cat-surface0);
        --color-success: var(--cat-green);
        --color-success-background: var(--cat-surface0);
        --color-categories-item-selected-font: var(--cat-text);
        --color-categories-item-border-selected: var(--cat-mauve);
        --color-autocomplete-font: var(--cat-subtext1);
        --color-autocomplete-border: var(--cat-surface0);
        --color-autocomplete-shadow: 0 2px 8px var(--cat-crust);
        --color-autocomplete-background: var(--cat-surface0);
        --color-autocomplete-background-hover: var(--cat-surface1);
        --color-answer-font: var(--cat-text);
        --color-answer-background: var(--cat-mantle);
        --color-result-background: var(--cat-mantle);
        --color-result-border: var(--cat-base);
        --color-result-url-font: var(--cat-subtext1);
        --color-result-vim-selected: var(--cat-surface0);
        --color-result-vim-arrow: var(--cat-mauve);
        --color-result-description-highlight-font: var(--cat-text);
        --color-result-link-font: var(--cat-mauve);
        --color-result-link-font-highlight: var(--cat-mauve);
        --color-result-link-visited-font: var(--cat-mauve);
        --color-result-publishdate-font: var(--cat-surface2);
        --color-result-engines-font: var(--cat-surface2);
        --color-result-search-url-border: var(--cat-surface2);
        --color-result-search-url-font: var(--cat-text);
        --color-result-detail-font: var(--cat-text);
        --color-result-detail-label-font: var(--cat-subtext0);
        --color-result-detail-background: var(--cat-base);
        --color-result-detail-hr: var(--cat-base);
        --color-result-detail-link: var(--cat-mauve);
        --color-result-detail-loader-border: rgba(255, 255, 255, 0.2);
        --color-result-detail-loader-borderleft: var(--cat-crust);
        --color-result-image-span-font: var(--cat-text);
        --color-result-image-span-font-selected: var(--cat-base);
        --color-result-image-background: var(--cat-mantle);
        --color-settings-tr-hover: var(--cat-surface0);
        --color-settings-engine-description-font: var(--cat-text);
        --color-settings-engine-group-background: var(--cat-surface0);
        --color-toolkit-badge-font: var(--cat-text);
        --color-toolkit-badge-background: var(--cat-surface0);
        --color-toolkit-kbd-font: var(--cat-text);
        --color-toolkit-kbd-background: var(--cat-mantle);
        --color-toolkit-dialog-border: var(--cat-mantle);
        --color-toolkit-dialog-background: var(--cat-mantle);
        --color-toolkit-tabs-label-border: var(--cat-base);
        --color-toolkit-tabs-section-border: var(--cat-base);
        --color-toolkit-select-background: var(--cat-surface0);
        --color-toolkit-select-border: var(--cat-surface0);
        --color-toolkit-select-background-hover: var(--cat-surface1);
        --color-toolkit-input-text-font: var(--cat-text);
        --color-toolkit-checkbox-onoff-off-background: var(--cat-surface0);
        --color-toolkit-checkbox-onoff-on-background: var(--cat-surface0);
        --color-toolkit-checkbox-onoff-on-mark-background: var(--cat-green);
        --color-toolkit-checkbox-onoff-on-mark-color: var(--cat-mantle);
        --color-toolkit-checkbox-onoff-off-mark-background: var(--cat-red);
        --color-toolkit-checkbox-onoff-off-mark-color: var(--cat-mantle);
        --color-toolkit-checkbox-label-background: var(--cat-base);
        --color-toolkit-checkbox-label-border: var(--cat-mantle);
        --color-toolkit-checkbox-input-border: var(--cat-mauve);
        --color-toolkit-engine-tooltip-border: var(--cat-surface0);
        --color-toolkit-engine-tooltip-background: var(--cat-surface0);
        --color-toolkit-loader-border: rgba(255, 255, 255, 0.2);
        --color-toolkit-loader-borderleft: var(--cat-crust);
        --color-doc-code: var(--cat-rosewater);
        --color-doc-code-background: var(--cat-mantle);
    }

    #search_logo svg :not([fill="none"]) {
        fill: var(--cat-mauve) !important;
    }
    #search_logo svg :not([stroke="none"]) {
        stroke: var(--cat-mauve) !important;
    }

    /* Additional cute tweaks */
    article.result {
      background-color: var(--color-result-background);
      border-radius: 0.75em;
      padding: 0.75em;
      margin: 0.5em;
      border: 1px solid var(--cat-surface0);
    }
    article.category-images {
      padding-bottom: 4em;
    }
    input[type="text"] {
        border-radius: 2em !important;
    }
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
  };

  config = lib.mkIf cfg.enable {
    # Ensure Podman is enabled
    myModules.podman.enable = true;

    # 1. Redis Container (Cache/Limiter)
    virtualisation.oci-containers.containers."searxng-redis" = {
      image = "docker.io/library/redis:alpine";
      cmd = [ "redis-server" "--save" "" "--appendonly" "no" ]; # Ephemeral cache, no persistence needed
      ports = [ "127.0.0.1:6379:6379" ];
    };

    # 2. SearXNG Container
    virtualisation.oci-containers.containers."searxng" = {
      image = "docker.io/searxng/searxng:latest";
      ports = [ "127.0.0.1:${toString cfg.port}:8080" ];
      environment = {
        "SEARXNG_BASE_URL" = "https://${cfg.domain}";
        "SEARXNG_REDIS_URL" = "redis://searxng-redis:6379"; # Talk to Redis directly via container DNS
        "SEARXNG_URL_BASE" = "https://${cfg.domain}"; 
      };
      environmentFiles = [
        # Contains SEARXNG_SECRET_KEY
        config.sops.templates."searxng.env".path
      ];
      extraOptions = [
        "--cap-drop=ALL"
        "--cap-add=CHOWN"
        "--cap-add=SETGID"
        "--cap-add=SETUID"
        "--cap-add=DAC_OVERRIDE"
        "--add-host=host.containers.internal:host-gateway"
      ];
      volumes = [
        "${config.sops.templates."searxng_settings.yml".path}:/etc/searxng/settings.yml:ro"
        "${catppuccinCss}:/etc/searxng/custom.css:ro"
      ];
    };

    # 3. Secrets Configuration
    # We generate the settings.yml dynamically using sops templates to inject secrets if needed,
    # or just to manage the config declaratively.
    sops.templates."searxng.env".content = ''
      SEARXNG_SECRET_KEY=${config.sops.placeholder.searxng_secret_key}
    '';

    sops.templates."searxng_settings.yml".content = ''
      use_default_settings: true
      
      general:
        debug: false
        instance_name: "Ashie Search"
        donations:
          patreon: false
          buymeacoffee: false
      
      search:
        safe_search: 0
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
      
      ui:
        static_use_hash: true
        custom_css: custom.css
        theme_args:
          simple_style: "auto"
      
      redis:
        url: redis://searxng-redis:6379/0
    '';
    
    # Placeholder secret definition (User must add this to secrets.yaml!)
    sops.secrets.searxng_secret_key = { };
  };
}
