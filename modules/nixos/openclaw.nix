{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.services.openclaw-service;
  openclawPkg = inputs.nix-openclaw.packages.${pkgs.system}.default;
in
{
  options.services.openclaw-service = {
    enable = mkEnableOption "OpenClaw AI Agent Service";

    user = mkOption {
      type = types.str;
      default = "kafka";
      description = "User to run OpenClaw as";
    };

    group = mkOption {
      type = types.str;
      default = "kafka";
      description = "Group to run OpenClaw as";
    };

    port = mkOption {
      type = types.int;
      default = 18789;
      description = "Port to listen on";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/openclaw";
      description = "Directory for OpenClaw data and workspace";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isNormalUser = true;
      linger = true;
      uid = 1001;
      group = cfg.group;
      description = "OpenClaw Service User";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = {
      gid = 1001;
    };

    sops.secrets."openclaw/discord_token" = {
      owner = cfg.user;
      group = cfg.group;
      key = "discord_bot_token";
    };

    sops.secrets."openclaw/glm_api_key" = {
      owner = cfg.user;
      group = cfg.group;
      key = "glm_api_key";
    };

    sops.secrets."openclaw/brave_api_key" = {
      owner = cfg.user;
      group = cfg.group;
      key = "searxng_brave_api_key";
    };

    sops.secrets."openclaw/master_api_key" = {
      owner = cfg.user;
      group = cfg.group;
      key = "master_api_key";
    };

    systemd.services.openclaw = {
      description = "OpenClaw AI Agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "openclaw"; # Creates /var/lib/openclaw
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = "10s";

      };

      environment = {
        OPENCLAW_CONFIG_PATH = "${cfg.dataDir}/config/openclaw.json";
        OPENCLAW_HOME = "${cfg.dataDir}";
        OPENCLAW_DATA_DIR = "${cfg.dataDir}/data";
        OPENCLAW_WORKSPACE_DIR = "${cfg.dataDir}/workspace";
        OPENCLAW_GATEWAY_TOKEN = "openclaw-local-token";
        XDG_RUNTIME_DIR = "/run/user/1001";
        DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1001/bus";
        # We need to ensure these directories exist.
      };

      preStart = ''
        mkdir -p ${cfg.dataDir}/config
        mkdir -p ${cfg.dataDir}/data
        mkdir -p ${cfg.dataDir}/workspace

        # Generate config.json
        cat > ${cfg.dataDir}/config/openclaw.json <<EOF
        {
          "gateway": {
            "mode": "local",
            "port": ${toString cfg.port},
            "bind": "loopback",
            "trustedProxies": [ "::1", "127.0.0.1", "10.88.0.0/16", "10.89.0.0/16" ],
            "controlUi": {
              "dangerouslyAllowHostHeaderOriginFallback": true,
              "allowedOrigins": [ "*" ]
            }
          },
          "agents": {
            "defaults": {
              "workspace": "${cfg.dataDir}/workspace",
              "model": { "primary": "cli/gemini-3.1-pro-preview" },
              "memorySearch": {
                "enabled": true,
                "provider": "local",
                "remote": {
                  "baseUrl": "http://localhost:11434"
                },
                "model": "nomic-embed-text"
              }
            }
          },
          "channels": {
            "discord": {
              "enabled": true,
              "token": "$(cat ${config.sops.secrets."openclaw/discord_token".path})",
              "allowFrom": [ "1178286690750693419", "*" ],
              "groupPolicy": "open",
              "dmPolicy": "open"
            }
          },
          "commands": {
            "native": true,
            "nativeSkills": "auto",
            "restart": true,
            "ownerDisplay": "raw"
          },
          "tools": {
            "exec": { "security": "full", "ask": "off" }
          },
          "models": {
            "mode": "merge",
            "providers": {
              "ollama": {
                "baseUrl": "http://127.0.0.1:11434",
                "models": [
                  { "id": "nomic-embed-text", "name": "nomic-embed-text" },
                  { "id": "mxbai-embed-large", "name": "mxbai-embed-large" },
                  { "id": "llama3.2", "name": "llama3.2", "reasoning": true, "contextWindow": 128000, "maxTokens": 128000 },
                  { "id": "llama3.1", "name": "llama3.1", "reasoning": true, "contextWindow": 128000, "maxTokens": 128000 }
                ]
              },
              "zai": {
                "baseUrl": "https://api.z.ai/api/coding/paas/v4",
                "apiKey": "$(cat ${config.sops.secrets."openclaw/glm_api_key".path})",
                "models": [
                  { "id": "glm-4.7", "name": "GLM 4.7", "reasoning": true, "contextWindow": 128000, "maxTokens": 128000 },
                  { "id": "glm-5", "name": "GLM 5", "reasoning": true, "contextWindow": 128000, "maxTokens": 128000 }
                ]
              },
              "cli": {
                "api": "openai-completions",
                "baseUrl": "http://localhost:8045/cli/v1",
                "apiKey": "$(cat ${config.sops.secrets."openclaw/master_api_key".path})",
                "models": [
                  { "id": "gemini-3.1-pro-preview", "name": "gemini-3.1-pro-preview", "contextWindow": 1000000, "maxTokens": 65536 },
                  { "id": "gemini-3-flash-preview", "name": "gemini-3-flash-preview", "contextWindow": 128000, "maxTokens": 65536 }
                ]
              }
            }
          },
          "skills": {
            "entries": {
              "mcporter": { "enabled": true }
            }
          },
          "env": {
            "vars": {
              "BRAVE_API_KEY": "$(cat ${config.sops.secrets."openclaw/brave_api_key".path})",
              "OPENCLAW_BRAVE_API_KEY": "$(cat ${config.sops.secrets."openclaw/brave_api_key".path})"
            }
          }
        }
        EOF
      '';

      script = "${openclawPkg}/bin/openclaw gateway run --port ${toString cfg.port}";
    };
  };
}
