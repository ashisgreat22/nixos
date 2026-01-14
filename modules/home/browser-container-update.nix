# Browser Container Update Module (Home Manager)
# Provides: Auto-update timer for browser container images
#
# Usage:
#   myModules.browserContainerUpdate = {
#     enable = true;
#     repositoryPath = "/home/user/nixos";
#     schedule = "weekly";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.browserContainerUpdate;
in
{
  options.myModules.browserContainerUpdate = {
    enable = lib.mkEnableOption "Browser container auto-update timer";

    repositoryPath = lib.mkOption {
      type = lib.types.str;
      default = config.myModules.common.repoPath;
      description = "Path to repository containing container Dockerfiles";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "systemd calendar expression for update schedule";
    };

    randomDelay = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "Random delay before running update";
    };

    browsers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "firefox"
          "tor-browser"
          "thorium"
        ]
      );
      default = [
        "firefox"
        "tor-browser"
        "thorium"
      ];
      description = "Which browser containers to update";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.browser-containers-update = {
      Unit = {
        Description = "Update browser container images";
      };

      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "update-browser-containers" ''
          set -e
          REPO_DIR="${cfg.repositoryPath}"

          ${lib.optionalString (builtins.elem "firefox" cfg.browsers) ''
            echo "=== Updating Firefox container ==="
            ${pkgs.podman}/bin/podman build --pull --no-cache \
              -t localhost/firefox-wayland:latest \
              "$REPO_DIR/containers/firefox-wayland/"
          ''}

          ${lib.optionalString (builtins.elem "tor-browser" cfg.browsers) ''
            echo "=== Updating Tor Browser container ==="
            ${pkgs.podman}/bin/podman build --pull --no-cache \
              -t localhost/tor-browser-wayland:latest \
              "$REPO_DIR/containers/tor-browser-wayland/"
          ''}

          ${lib.optionalString (builtins.elem "thorium" cfg.browsers) ''
            echo "=== Updating Thorium container ==="
            ${pkgs.podman}/bin/podman build --pull --no-cache \
              -t localhost/thorium-wayland:latest \
              "$REPO_DIR/containers/thorium-wayland/"
          ''}

          echo "=== Cleaning old images ==="
          ${pkgs.podman}/bin/podman image prune -f

          echo "=== Update complete ==="
          ${pkgs.libnotify}/bin/notify-send "Browser Containers" "Updated browser containers" --icon=security-high
        '';
      };
    };

    systemd.user.timers.browser-containers-update = {
      Unit = {
        Description = "Weekly browser container update timer";
      };

      Timer = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = cfg.randomDelay;
      };

      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
