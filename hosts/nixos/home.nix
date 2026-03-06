{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ../../modules/home-manager/gluetun-user.nix
    ../../modules/home-manager/cosmic.nix
    inputs.sops-nix.homeManagerModules.sops
    # inputs.steam-config-nix.homeModules.default
    inputs.catppuccin.homeManagerModules.catppuccin
    inputs.nixvim.homeManagerModules.nixvim
    # inputs.unified-router-mcp.homeManagerModules.default
    ../../modules/home-manager # Import all Home Manager modules
    ./home-modules.nix # Host-specific module configuration
    ./home/fastfetch.nix
    ./home/vscode.nix
    ./home/kitty.nix
    ./home/steam.nix
    ./home/mangohud.nix
    ./home/starship.nix
    ./home/opencode.nix
    ./home/fish.nix
    ./home/git.nix
    ./home/xdg.nix
    ./home/fonts.nix
  ];

  home.packages = [
    pkgs.mimalloc
    pkgs.jellyfin-media-player
    pkgs.joplin-desktop
    pkgs.bemoji
    pkgs.wtype
  ];

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/ashie/.config/sops/age/keys.txt";

  sops.secrets.master_api_key = { };
  sops.secrets.discord_bot_token = { };
  sops.secrets.searxng_brave_api_key = { };
  sops.secrets.github_token = { };

  # Unified Router MCP Servers
  # services.unified-router-mcp = {
  #   enable = true;
  #   databasePath = "/home/ashie/nixos/unified-router/data/database.db";
  #   logPath = "/home/ashie/nixos/unified-router/server.log";
  # };

  home.username = "ashie";
  home.homeDirectory = "/home/ashie";
  home.stateVersion = "25.05";

  services.polling-rate-switcher.enable = true;
  services.antigravity2api = {
    enable = true;
    credentials = {
      username = "ashie";
      password = "AshieAntigravity2024!";
      apiKey = "sk-antigravity-local-key";
      glmApiKeyPath = "/run/secrets/glm_api_key";
    };
  };

  programs.bash = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.tealdeer = {
    enable = true;
    settings = {
      updates = {
        auto_update = true;
        auto_update_interval_hours = 48;
      };
    };
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-esr; # Use standard package so HM can manage profiles/policies
    arkenfox = {
      enable = true;
      version = "140.0"; # Match ESR version
    };
    profiles.ashie = {
      id = 0;
      extensions = with inputs.firefox-addons.legacyPackages.${pkgs.system}.firefox-addons; [
        ublock-origin
        bitwarden
        sponsorblock
      ];
      search = {
        default = "AshisGreat";
        force = true;
        engines = {
          "AshisGreat" = {
            urls = [{
              template = "https://search.ashisgreat.xyz/search";
              params = [
                { name = "q"; value = "{searchTerms}"; }
              ];
            }];
            iconUpdateURL = "https://search.ashisgreat.xyz/favicon.ico";
            updateInterval = 24 * 60 * 60 * 1000; # every day
            definedAliases = [ "@ag" ];
          };
          "Brave Search" = {
            urls = [{
              template = "https://search.brave.com/search";
              params = [
                { name = "q"; value = "{searchTerms}"; }
              ];
            }];
            iconUpdateURL = "https://search.brave.com/favicon.ico";
            updateInterval = 24 * 60 * 60 * 1000; # every day
            definedAliases = [ "@b" ];
          };
        };
      };
      arkenfox = {
        enable = true;
        "0000".enable = true; # Top-level overrides
        "0100".enable = true; # Startup
        "0200".enable = true; # Geolocation
        "0300".enable = true; # Browser Features
        "0400".enable = true; # Safe Browsing
        "0600".enable = true; # Block Implicit Outbound
        "0700".enable = true; # DNS / DoH
        "0800".enable = true; # Search Bar / Forms / History
        "0900".enable = true; # Passwords
        "1000".enable = true; # Disk Cache / Antifingerprinting
        "1200".enable = true; # HTTPS
        "1600".enable = true; # Referers
        "1700".enable = true; # Containers
        "2000".enable = true; # Plugins / Media
        "2400".enable = true; # DOM
        "2600".enable = true; # Storage
        "2700".enable = true; # Enhanced Tracking Protection
        "2800".enable = true; # Shutdown & Sanitizing
        "4500".enable = true; # RFP (Resist Fingerprinting)
        "5000".enable = true; # Optional OPSEC
        "5500".enable = true; # Optional Hardening
        "6000".enable = true; # DON'T TOUCH
        "7000".enable = true; # DON'T TOUCH
        "8000".enable = true; # DON'T TOUCH
        "9000".enable = true; # DON'T TOUCH
      };
    };
  };

  systemd.user.services.ydotoold = {
    Unit = {
      Description = "ydotool daemon";
    };
    Service = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path %t/ydotoold.sock";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}