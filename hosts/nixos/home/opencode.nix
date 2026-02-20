{
  config,
  pkgs,
  inputs,
  ...
}:
{
  home.packages = [
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
}
