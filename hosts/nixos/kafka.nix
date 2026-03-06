{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  home.username = "kafka";
  home.homeDirectory = "/home/kafka";
  home.stateVersion = "25.05";

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/kafka/.config/sops/age/keys.txt";

  sops.secrets.openai_api_key = { };
  sops.secrets.github_token = { };

  programs.openclaw = {
    enable = true;
    stateDir = "/home/kafka/openclaw";
    workspaceDir = "/home/kafka/openclaw/workspace";
    config = {
      gateway = {
        port = 18789;
        bind = "loopback";
        trustedProxies = [ "::1" "127.0.0.1" "10.88.0.0/16" "10.89.0.0/16" ];
        auth = {
          mode = "none";
        };
        controlUi = {
          dangerouslyAllowHostHeaderOriginFallback = true;
          allowedOrigins = [ "*" ];
        };
      };
      channels = {
        discord = {
          enabled = true;
          token = "/run/secrets/openclaw-discord-token";
          allowFrom = [ "1178286690750693419" "*" ];
          groupPolicy = "open";
          dmPolicy = "open";
        };
      };
      agents = {
        defaults = {
          workspace = "/home/kafka/openclaw/workspace";
          model = {
            primary = "zai/glm-4.7";
          };
        };
      };
      commands = {
        native = true;
        nativeSkills = "auto";
        restart = true;
        ownerDisplay = "raw";
      };
      tools = {
        exec = {
          security = "full";
          ask = "off";
        };
      };
      models = {
        mode = "merge";
        providers.zai = {
          baseUrl = "https://api.z.ai/api/coding/paas/v4";
          apiKey = "e77f2c392cb942eca9d0407eebc75549.XG7ikxT2kBEQUPYx";
          models = [
            {
              id = "glm-4.7";
              name = "GLM 4.7";
              reasoning = true;
              contextWindow = 128000;
              maxTokens = 128000;
            }
            {
              id = "glm-5";
              name = "GLM 5";
              reasoning = true;
              contextWindow = 128000;
              maxTokens = 128000;
            }
          ];
        };
      };
      skills.entries.mcporter.enabled = true;
    };
  };
}
