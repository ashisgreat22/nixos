{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Wrap Antigravity in an FHS environment to support dynamically linked binaries
  antigravityFHS = pkgs.buildFHSEnv {
    name = "antigravity";

    targetPkgs =
      pkgs:
      (with pkgs; [
        antigravity
        chromium
        # Common libraries for dynamically linked binaries
        gcc
        glibc
        stdenv.cc.cc
        zlib
        openssl
        curl
        libgcc
        glib
        gtk3
        libsecret
        libnotify
        nss
        nspr
        alsa-lib
        cups
        dbus
        expat
        libdrm
        libxkbcommon
        mesa
        pango
        cairo
        # X11 libraries
        xorg.libX11
        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXrandr
        xorg.libxcb
      ]);

    # Run antigravity binary when the FHS env is invoked
    runScript = pkgs.writeShellScript "antigravity-wrapper" ''
      unset LD_PRELOAD

      # Use a wrapper for bash that ignores user configuration
      export SHELL=${pkgs.writeShellScript "bash-sandboxed" ''exec ${pkgs.bash}/bin/bash --noprofile --norc "$@"''}

      exec ${pkgs.antigravity}/bin/antigravity "$@"
    '';

    # Ensure the FHS environment is set up properly
    profile = ''
      export LD_LIBRARY_PATH=/usr/lib:/usr/lib64:$LD_LIBRARY_PATH
    '';

    extraBwrapArgs = [
      "--tmpfs"
      "/home/ashie/.config/fish"
    ];

    extraBindMounts = [
      "/etc/subuid"
      "/etc/subgid"
    ];
  };

  # Wrap the FHS environment to add product.json symlink where Home Manager expects it
  antigravityWrapped = pkgs.symlinkJoin {
    name = "antigravity-wrapped";
    paths = [ antigravityFHS ];
    postBuild = ''
      # Link product.json from the original antigravity package
      ln -sf ${pkgs.antigravity}/lib/antigravity/resources/app/product.json $out/product.json
    '';
    # Pass through required attributes for Home Manager vscode module
    passthru = {
      inherit (pkgs.antigravity) pname version;
    };
  };

  # Launcher for the regular non-sandboxed environment (Native)
  antigravityNative = pkgs.writeShellScriptBin "antigravity-native" ''
    unset LD_PRELOAD
    exec ${pkgs.antigravity}/bin/antigravity "$@"
  '';

  # Explicit launcher for the FHS environment (same as default)
  antigravityFHSLauncher = pkgs.writeShellScriptBin "antigravity-fhs" ''
    exec ${antigravityWrapped}/bin/antigravity "$@"
  '';

  # Helper to adapt VS Code extensions for Antigravity
  # Home Manager expects extensions to be in share/antigravity/extensions based on the package name,
  # but standard extensions are in share/vscode/extensions.
  adaptToAntigravity =
    ext:
    pkgs.symlinkJoin {
      name = "${ext.name}-antigravity";
      paths = [ ext ];
      # Ensure passthru attributes are preserved (though symlinkJoin usually handles this, specific ones might help)
      inherit (ext) meta;
      postBuild = ''
        mkdir -p $out/share/antigravity
        ln -sf ${ext}/share/vscode/extensions $out/share/antigravity/extensions
      '';
    };
in
{
  home.packages = [
    antigravityNative
    antigravityFHSLauncher
  ];

  programs.vscode = {
    enable = true;
    package = antigravityWrapped;

    # Allow mutable extensions dir so Antigravity can create extensions.json
    mutableExtensionsDir = true;

    # extensions = [
    #   (pkgs.vscode-utils.extensionFromVscodeMarketplace {
    #     name = "x";
    #     publisher = "x";
    #     version = "x.x.x";
    #     sha256 = "sha256-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=";
    #   })
    # ];

    profiles.default = {
      # Disable update checks (not applicable for Nix-managed packages)
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;

      # Extensions from nixpkgs
      extensions = map adaptToAntigravity (
        with pkgs.vscode-extensions;
        [
          # Theme & Icons
          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons

          # Git
          eamodio.gitlens

          # C/C++
          llvm-vs-code-extensions.vscode-clangd

          # Nix
          jnoortheen.nix-ide

          # Python
          ms-python.python
          ms-python.debugpy

          # Go
          golang.go

          # Java (RedHat + vscjava)
          redhat.java
          vscjava.vscode-java-debug
          vscjava.vscode-java-dependency
          vscjava.vscode-java-pack
          vscjava.vscode-java-test
          vscjava.vscode-gradle
          vscjava.vscode-maven

          # PHP
          bmewburn.vscode-intelephense-client
          xdebug.php-debug

          # Ruby
          shopify.ruby-lsp

          # Docker & Containers
          ms-azuretools.vscode-docker

          # Formatters
          esbenp.prettier-vscode
        ]
      );

      # User settings (settings.json equivalent)
      userSettings = {
        # Existing settings from your current settings.json
        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "catppuccin-mocha";
        "terminal.integrated.shellIntegration.enabled" = false;
        "python.languageServer" = "Default";
        "json.schemaDownload.enable" = true;
        "git.autofetch" = true;
        "git.confirmSync" = false;
        "explorer.confirmDelete" = false;
        "redhat.telemetry.enabled" = false;

        # MCP Server configuration for Continue.dev / Cline
        # These servers provide AI agents with direct access to:
        # - Database inspection (sqlite-inspector)
        # - Log analysis (pino-parser)
        # - API testing (api-tester)
        "mcp.servers" = {
          "unified-router-sqlite" = {
            command = "mcp-sqlite-inspector";
            env = {
              DEFAULT_DB_PATH = "/home/ashie/nixos/unified-router/data/database.db";
            };
          };
          "unified-router-logs" = {
            command = "mcp-pino-parser";
            env = {
              DEFAULT_LOG_PATH = "/home/ashie/nixos/unified-router/server.log";
            };
          };
          "unified-router-api" = {
            command = "mcp-api-tester";
            env = {
              ALLOWED_HOSTS = "localhost,127.0.0.1";
              DEFAULT_PORT = "9090";
            };
          };
          #   "nixos" = {
          #     command = "${inputs.mcp-nixos.packages.${pkgs.system}.default}/bin/mcp-nixos";
          #   };
        };
      };
    };
  };

  # Antigravity MCP Server Configuration
  home.file.".gemini/antigravity/mcp_config.json" = {
    force = true; # Allow overwriting existing file created by Antigravity
    text = builtins.toJSON {
      mcpServers = {
        unified-router-sqlite = {
          command = "mcp-sqlite-inspector";
          env = {
            DEFAULT_DB_PATH = "/home/ashie/nixos/unified-router/data/database.db";
          };
        };
        unified-router-logs = {
          command = "mcp-pino-parser";
          env = {
            DEFAULT_LOG_PATH = "/home/ashie/nixos/unified-router/server.log";
          };
        };
        unified-router-api = {
          command = "mcp-api-tester";
          env = {
            ALLOWED_HOSTS = "localhost,127.0.0.1";
            DEFAULT_PORT = "9090";
          };
        };
        # nixos = {
        #   command = "${inputs.mcp-nixos.packages.${pkgs.system}.default}/bin/mcp-nixos";
        # };
      };
    };
  };
}
