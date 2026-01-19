{
  description = "Modular NixOS Configuration with Hyprland";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    steam-config-nix = {
      url = "github:different-name/steam-config-nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    prismlauncher = {
      url = "github:PrismLauncher/PrismLauncher?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-bwrapper = {
      url = "github:Naxdy/nix-bwrapper?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode-flake = {
      url = "github:AodhanHayter/opencode-flake?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:YaLTeR/niri?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mcp-nixos = {
      url = "github:utensils/mcp-nixos?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    catppuccin-userstyles = {
      url = "github:catppuccin/userstyles";
      flake = false;
    };

    nixvim = {
      url = "github:nix-community/nixvim?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      noctalia,
      lanzaboote,
      niri,
      cosmic-manager,
      nixflix,
      ...
    }@inputs:
    {
      # Expose reusable NixOS modules for others to import
      nixosModules = {
        security = import ./modules/system/security.nix;
        kernelHardening = import ./modules/system/kernel-hardening.nix;
        secureBoot = import ./modules/system/secure-boot.nix;
        dnsOverTls = import ./modules/system/dns-over-tls.nix;
        cloudflareFirewall = import ./modules/system/cloudflare-firewall.nix;
        caddyCloudflare = import ./modules/system/caddy-cloudflare.nix;
        podman = import ./modules/system/podman.nix;
        browserVpn = import ./modules/system/browser-vpn.nix;
        default = import ./modules;
      };

      # Expose reusable Home Manager modules
      homeManagerModules = {
        hyprlandCatppuccin = import ./modules/home/hyprland-catppuccin.nix;
        gluetunUser = import ./modules/home/gluetun-user.nix;
        qbittorrentVpn = import ./modules/home/qbittorrent-vpn.nix;
        browserContainerUpdate = import ./modules/home/browser-container-update.nix;
        protonCachyosUpdater = import ./modules/home/proton-cachyos-updater.nix;
        default = import ./modules/home;
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./modules # Import all system modules
          inputs.sops-nix.nixosModules.sops
          inputs.nixflix.nixosModules.default
          home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.nixvim.nixosModules.nixvim
          {
            home-manager = {
              extraSpecialArgs = { inherit inputs; };
              sharedModules = [ inputs.cosmic-manager.homeManagerModules.cosmic-manager ];
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users.ashie = import ./home.nix;
            };
          }
          ./modules/system/impermanence.nix
        ];
      };

      nixosConfigurations.impermanence = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./modules
          inputs.sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.nixvim.nixosModules.nixvim
          {
            home-manager = {
              extraSpecialArgs = { inherit inputs; };
              sharedModules = [ inputs.cosmic-manager.homeManagerModules.cosmic-manager ];
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users.ashie = import ./home.nix;
            };
          }
          ./modules/system/impermanence.nix
        ];
      };
    };
}
