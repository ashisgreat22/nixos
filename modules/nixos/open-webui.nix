# Open WebUI Module (System)
# Provides: Open WebUI chat interface as system container
#
# Usage:
#   myModules.openWebUI = {
#     enable = true;
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.openWebUI;
in
{
  options.myModules.openWebUI = {
    enable = lib.mkEnableOption "Open WebUI chat interface (System Service)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/open-webui/open-webui:main";
      description = "Open WebUI container image";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/open-webui";
      description = "Path to Open WebUI data directory";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Host port for Open WebUI";
    };

    # Networking Defaults:
    # - Ollama is on the SAME system network (antigravity-net), so we use container name 'ollama'.
    # - Unified Router is a USER container, so we must access via Host gateway.
    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://ollama:11434";
      description = "URL to Ollama API (Internal Container Network)";
    };

    openaiBaseUrl = lib.mkOption {
      type = lib.types.str;
      # 10.88.0.1 is default podman gateway, or use host.containers.internal if available
      default = "http://host.containers.internal:6767/v1";
      description = "URL to OpenAI-compatible API (Unified Router on Host)";
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/open_webui_env";
      description = "Path to environment file with secrets";
    };

    apiKeyEnvFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/rendered/api_key.env";
      description = "Path to API key environment file";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure data directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
    ];

    systemd.services.open-webui = {
      description = "Open WebUI Container (System)";
      after = [
        "network-online.target"
        "ollama.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "ollama.service" ]; # It depends on Ollama for local inference often

      serviceConfig = {
        Restart = "always";

        # Hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = false;
        ProtectControlGroups = false; # Podman needs cgroups
        ProtectKernelModules = true;

        # Allow Podman to write to state and data
        ReadWritePaths = [
          "/var/lib/containers"
          "/run"
          "/etc/containers" # Network configs live here
          cfg.dataDir
        ];

        # ExecStartPre to cleanup
        ExecStartPre = [
          "-${pkgs.podman}/bin/podman stop open-webui"
          "-${pkgs.podman}/bin/podman rm open-webui"
          "${pkgs.podman}/bin/podman pull ${cfg.image}"
          "${pkgs.podman}/bin/podman network create antigravity-net --ignore"
          # Fix ownership for UserNS (container user maps to host UID 200000)
          "${pkgs.coreutils}/bin/chown -R 200000:200000 ${cfg.dataDir}"
        ];
        ExecStart = ''
          ${pkgs.podman}/bin/podman run --rm --name open-webui \
            --network=antigravity-net \
            --dns=8.8.8.8 \
            --userns=auto \
            -e ENABLE_PERSISTENT_CONFIG=True \
            -e OPENAI_API_BASE_URL=${cfg.openaiBaseUrl} \
            -e OLLAMA_BASE_URL=${cfg.ollamaUrl} \
            -e ENABLE_RAG_WEB_SEARCH=True \
            -e RAG_WEB_SEARCH=True \
            -e RAG_WEB_SEARCH_ENGINE=duckduckgo \
            -e RAG_WEB_SEARCH_RESULT_COUNT=3 \
            -e ENABLE_RAG=True \
            --env-file=${cfg.envFile} \
            --env-file=${cfg.apiKeyEnvFile} \
            -v ${cfg.dataDir}:/app/backend/data:U \
            --add-host=host.containers.internal:host-gateway \
            -p 127.0.0.1:${toString cfg.port}:8080 \
            ${cfg.image}
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop open-webui";
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
