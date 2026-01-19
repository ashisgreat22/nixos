{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./modules/home/gluetun-user.nix
    ./modules/home/cosmic.nix
    inputs.sops-nix.homeManagerModules.sops
    inputs.steam-config-nix.homeModules.default
    inputs.catppuccin.homeManagerModules.catppuccin
    inputs.nixvim.homeManagerModules.nixvim
    # inputs.unified-router-mcp.homeManagerModules.default
    ./modules/home # Import all Home Manager modules
    ./hosts/nixos/home-modules.nix # Host-specific module configuration
    ./home/fastfetch.nix
    ./home/vscode.nix
    ./home/kitty.nix
    ./home/steam.nix
    ./home/mangohud.nix
    ./home/starship.nix
  ];

  home.packages = [
    pkgs.mimalloc
    pkgs.jellyfin-media-player
    pkgs.bemoji
    pkgs.wtype
    (pkgs.writeShellScriptBin "opencode" ''
      export OPENAI_BASE_URL="https://api.ashisgreat.xyz/v1"
      export OPENAI_API_KEY="$(cat ${config.sops.secrets.master_api_key.path})"
      export OPENCODE_DISABLE_DEFAULT_PLUGINS=true

      # Ensure config directory exists
      mkdir -p $HOME/.config/opencode

      # Force remove config.json if it is a symlink to ensure we can write to it
      if [ -L $HOME/.config/opencode/config.json ]; then
         rm -f $HOME/.config/opencode/config.json
      fi

      # Validate permissions and force write correct config
      # We verify if we can write to it, if not (e.g. read-only file), we remove it
      if [ -f $HOME/.config/opencode/config.json ] && [ ! -w $HOME/.config/opencode/config.json ]; then
         rm -f $HOME/.config/opencode/config.json
      fi

      # Always overwrite config.json to ensure correct settings
      cat > $HOME/.config/opencode/config.json <<EOF
      {
        "model": "openai/gpt-4o",
        "disabled_providers": ["opencode-anthropic-auth", "anthropic", "github"],
        "plugin": []
      }
      EOF

      # Clear broken plugin from cache if it exists (one-time cleanup)
      if [ -d "$HOME/.cache/opencode/node_modules/opencode-anthropic-auth" ]; then
        rm -rf "$HOME/.cache/opencode"
      fi

      exec ${inputs.opencode-flake.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/opencode "$@"
    '')
  ];

  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/ashie/.config/sops/age/keys.txt";

  sops.secrets.master_api_key = { };

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
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      hyfetch
    '';
    plugins = [
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
      {
        name = "puffer";
        src = pkgs.fishPlugins.puffer.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "pisces";
        src = pkgs.fishPlugins.pisces.src;
      }
    ];
    shellAliases = {
      btw = "echo i use hyprland btw";
      vi = "nvim";
      vim = "nvim";
      "67" = "nh os switch";
    };
  };

  programs.bash = {
    enable = true;
  };

  programs.git = {
    enable = true;
    settings.user.name = "ashisgreat22";
    settings.user.email = "dev@ashisgreat.xyz";
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
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

  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      serif = [ "ComicShannsMono Nerd Font" ];
      sansSerif = [ "ComicShannsMono Nerd Font" ];
      monospace = [ "ComicShannsMono Nerd Font Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  xdg.desktopEntries.youtube = {
    name = "YouTube";
    genericName = "Video Player";
    exec = "brave --app=https://youtube.com";
    terminal = false;
    categories = [
      "Network"
      "Video"
      "AudioVideo"
    ];
    icon = "youtube";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [
        "onlyoffice-desktopeditors.desktop"
      ];
      "application/msword" = [ "onlyoffice-desktopeditors.desktop" ];
      "text/html" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/http" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/https" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/about" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/unknown" = [ "nix.bwrapper.firefox.desktop" ];
      "application/xhtml+xml" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-htm" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-html" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-shtml" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-xhtml" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-xht" = [ "nix.bwrapper.firefox.desktop" ];
      "application/pdf" = [ "nix.bwrapper.firefox.desktop" ];
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
