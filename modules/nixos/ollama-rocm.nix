# Ollama ROCm Module (System)
# Provides: Ollama LLM server with AMD ROCm GPU passthrough as system container
#
# Usage:
#   myModules.ollamaRocm = {
#     enable = true;
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.ollamaRocm;
in
{
  options.myModules.ollamaRocm = {
    enable = lib.mkEnableOption "Ollama with ROCm GPU passthrough (System Service)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/ollama/ollama:rocm";
      description = "Ollama ROCm container image";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ollama";
      description = "Path to Ollama data directory (models, etc.)";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Ollama API port";
    };

    hsaGfxVersion = lib.mkOption {
      type = lib.types.str;
      default = "12.0.1";
      description = "HSA_OVERRIDE_GFX_VERSION for AMD GPU compatibility";
    };

    # Note: For system podman, usually we don't need group permissions if running as root,
    # but passing devices needs strictly correct flags.
    # We will assume root execution for simplicity and GPU access.

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      description = "Duration to keep model in memory (e.g. 5m, 1h). Set to 0 to unload immediately.";
    };

    # Performance Tuning
    numParallel = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "OLLAMA_NUM_PARALLEL: Concurrent requests (keep low for speed)";
    };

    maxLoadedModels = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "OLLAMA_MAX_LOADED_MODELS: Max models in memory";
    };

    numThreads = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 6; # Optimized for Ryzen 5600X (physical cores)
      description = "OLLAMA_NUM_THREADS: CPU threads for inference";
    };

    processPriority = lib.mkOption {
      type = lib.types.int;
      default = -10;
      description = "Systemd Nice priority (lower is higher priority, range -20 to 19)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure data directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    systemd.services.ollama = {
      description = "Ollama ROCm Container (System)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Restart = "always";
        Nice = cfg.processPriority;

        # Hardening
        ProtectSystem = "full";
        ProtectHome = false;
        PrivateTmp = true;
        ProtectKernelTunables = false; # Needed for Podman (BPF, etc)
        ProtectControlGroups = false; # Podman needs cgroups
        ProtectKernelModules = true;

        # Allow Podman to write to state and data
        ReadWritePaths = [
          "/var/lib/containers"
          "/run" # Podman needs to write to sockets and runtime dirs in /run
          "/etc/containers" # Network configs live here
          cfg.dataDir
        ];

        # ExecStartPre to cleanup old container and create net if needed.
        # Note: 'podman' in system context sees system containers/networks.
        ExecStartPre = [
          "-${pkgs.podman}/bin/podman stop ollama"
          "-${pkgs.podman}/bin/podman rm ollama"
          "-${pkgs.podman}/bin/podman network rm antigravity-net"
          "${pkgs.podman}/bin/podman network create antigravity-net --ignore"

          # Fix permission issue where /var/lib/ollama is a symlink to /var/lib/private/ollama
          # which is not accessible by the subuid user (200000).
          (pkgs.writeShellScript "ollama-pre-start" ''
            DATA_DIR="${cfg.dataDir}"

            # Check if it is a symlink
            if [ -L "$DATA_DIR" ]; then
              echo "Detected symlink at $DATA_DIR. Removing and converting to directory..."
              TARGET=$(readlink -f "$DATA_DIR")
              rm "$DATA_DIR"
              mkdir -p "$DATA_DIR"
              
              # If the target existed and has data, copy it back (optional, but safe)
              if [ -d "$TARGET" ]; then
                echo "Restoring data from $TARGET..."
                cp -r "$TARGET"/* "$DATA_DIR/" || true
              fi
            else
              mkdir -p "$DATA_DIR"
            fi

            # Fix ownership for UserNS (container user maps to host UID 200000)
            ${pkgs.coreutils}/bin/chown -R 200000:200000 "$DATA_DIR"
            ${pkgs.coreutils}/bin/chmod 0755 "$DATA_DIR"
          '')
        ];
        ExecStart = ''
          ${pkgs.podman}/bin/podman run --rm --name ollama \
            --label "io.containers.autoupdate=registry" \
            --network=antigravity-net \
            --network-alias=ollama \
            --dns=8.8.8.8 \
            --device=/dev/kfd \
            --device=/dev/dri \
            --userns=auto \
            -e HSA_OVERRIDE_GFX_VERSION=${cfg.hsaGfxVersion} \
            -e OLLAMA_HOST=0.0.0.0 \
            -e OLLAMA_ORIGINS="*" \
            -e OLLAMA_KEEP_ALIVE=${cfg.keepAlive} \
            -e OLLAMA_NUM_PARALLEL=${toString cfg.numParallel} \
            -e OLLAMA_MAX_LOADED_MODELS=${toString cfg.maxLoadedModels} \
            ${
              lib.optionalString (cfg.numThreads != null) "-e OLLAMA_NUM_THREADS=${toString cfg.numThreads}"
            } \
            -v ${cfg.dataDir}:/root/.ollama:U \
            -p ${toString cfg.port}:11434 \
            ${cfg.image}
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop ollama";
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
