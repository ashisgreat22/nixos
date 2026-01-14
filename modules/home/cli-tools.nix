{ pkgs, ... }:
{
  programs = {
    # Modern replacement for 'ls'
    eza = {
      enable = true;
      icons = "auto";
      git = true;
      enableBashIntegration = true;
    };

    # A cat(1) clone with wings
    bat = {
      enable = true;
      config = {
        theme = "Catppuccin Mocha";
      };
    };

    # A smarter cd command
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      options = [
        "--cmd cd" # Replace cd with zoxide
      ];
    };

    # Command-line fuzzy finder
    fzf = {
      enable = true;
      enableBashIntegration = true;
    };

    # Modern grep replacement
    ripgrep.enable = true;

    # Modern find replacement
    fd.enable = true;

    # Magical Shell History
    atuin = {
      enable = true;
      enableFishIntegration = true;
      flags = [
        "--disable-up-arrow"
      ];
    };

    # Terminal Multiplexer
    zellij = {
      enable = true;
      enableFishIntegration = false;
      settings = {
        theme = "catppuccin-mocha";
        show_startup_tips = false;
      };
    };

    # Interactive Cheatsheet
    navi = {
      enable = true;
      enableFishIntegration = true;
    };
  };

  home.packages = with pkgs; [
    nh # Nix helper for faster rebuilds
  ];

  # Point nh to the flake location
  home.sessionVariables = {
    NH_FLAKE = "/home/ashie/nixos";
  };

  home.shellAliases = {
    cat = "bat";
    grep = "rg";
    find = "fd";
    top = "btm";
    ps = "procs";
    sed = "sd";
    du = "dust -r";

    # Enhanced eza aliases
    ls = "eza --icons=auto";
    ll = "eza --icons=auto --long --git";
    la = "eza --icons=auto --all";
    lla = "eza --icons=auto --all --long --git";
    tree = "eza --icons=auto --tree";
  };
}
