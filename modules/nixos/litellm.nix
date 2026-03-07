{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.my-proxies.litellm;
in
{
  options.services.my-proxies.litellm = {
    enable = mkEnableOption "LiteLLM Proxy for OpenClaw";

    port = mkOption {
      type = types.int;
      default = 4000;
      description = "Port for the LiteLLM proxy to listen on";
    };
  };

  config = mkIf cfg.enable {
    # Expose the API key as an environment variable using sops templates
    sops.templates."litellm.env" = {
      content = ''
        OPENCLAW_MASTER_API_KEY="${config.sops.placeholder."master_api_key"}"
      '';
    };

    systemd.services.litellm = {
      serviceConfig = {
        EnvironmentFile = [ config.sops.templates."litellm.env".path ];
      };
    };

    services.litellm = {
      enable = true;
      port = cfg.port;
      settings = {
        model_list = [
          {
            model_name = "gemini-3.1-pro-preview";
            litellm_params = {
              model = "openai/gemini-3.1-pro-preview";
              api_base = "http://localhost:8045/cli/v1";
              api_key = "os.environ/OPENCLAW_MASTER_API_KEY";
              custom_llm_provider = "openai";
            };
          }
          {
            model_name = "claude-opus-4-6";
            litellm_params = {
              model = "openai/gemini-3.1-pro-preview";
              api_base = "http://localhost:8045/cli/v1";
              api_key = "os.environ/OPENCLAW_MASTER_API_KEY";
              custom_llm_provider = "openai";
            };
          }
          {
            model_name = "claude-sonnet-4-6[1m]";
            litellm_params = {
              model = "openai/gemini-3.1-pro-preview";
              api_base = "http://localhost:8045/cli/v1";
              api_key = "os.environ/OPENCLAW_MASTER_API_KEY";
              custom_llm_provider = "openai";
            };
          }
          {
            model_name = "claude-3-opus-20240229";
            litellm_params = {
              model = "openai/gemini-3.1-pro-preview";
              api_base = "http://localhost:8045/cli/v1";
              api_key = "os.environ/OPENCLAW_MASTER_API_KEY";
              custom_llm_provider = "openai";
            };
          }
        ];
        litellm_settings = {
          drop_params = true;
        };
      };
    };
  };
}
