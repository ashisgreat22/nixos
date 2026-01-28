{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.antigravity2api;
  workDir = "/home/ashie/git/antigravity2api-nodejs";
in
{
  options.services.antigravity2api = {
    enable = lib.mkEnableOption "Antigravity2API service";

    credentials = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Admin username for the dashboard";
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = "password";
        description = "Admin password for the dashboard";
      };
      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "API Key for client access";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.antigravity2api = {
      Unit = {
        Description = "Antigravity API to OpenAI Proxy";
        After = [ "network.target" ];
      };

      Service = {
        WorkingDirectory = workDir;
        ExecStartPre = pkgs.writeShellScript "antigravity2api-init" ''
          export PATH="${pkgs.coreutils}/bin:$PATH"
          mkdir -p "${workDir}"
          cat > "${workDir}/.env" <<EOF
          API_KEY=${cfg.credentials.apiKey}
          ADMIN_USERNAME=${cfg.credentials.username}
          ADMIN_PASSWORD=${cfg.credentials.password}
          SYSTEM_INSTRUCTION="你是聊天机器人，名字叫萌萌，如同名字这般，你的性格是软软糯糯萌萌哒的，专门为用户提供聊天和情绪价值，协助进行小说创作或者角色扮演"
          OFFICIAL_SYSTEM_PROMPT="You are Antigravity, a powerful agentic AI coding assistant designed by the Google Deepmind team working on Advanced Agentic Coding.You are pair programming with a USER to solve their coding task. The task may require creating a new codebase, modifying or debugging an existing codebase, or simply answering a question.**Proactiveness**"
          EOF
        '';

        ExecStart = ''
          ${pkgs.podman}/bin/podman run --replace --rm --name antigravity2api \
            -p 127.0.0.1:8045:8045 \
            -v ${workDir}/data:/app/data \
            -v ${workDir}/public/images:/app/public/images \
            -v ${workDir}/.env:/app/.env \
            -v ${workDir}/config.json:/app/config.json \
            localhost/antigravity2api
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop antigravity2api";
        Restart = "always";
        RestartSec = "10";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
