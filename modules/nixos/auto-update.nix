# Automatic Updates Module
# Provides:
# 1. Weekly Nix flake updates for the system configuration
# 2. Daily NixOS system upgrades via system.autoUpgrade
# 3. Daily Podman container updates for services with 'io.containers.autoupdate' label

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.autoUpdate;
  repoPath = "/home/ashie/nixos";
in
{
  options.myModules.autoUpdate = {
    enable = lib.mkEnableOption "system-wide automatic updates";
  };

  config = lib.mkIf cfg.enable {
    # 1. NixOS System Upgrades
    system.autoUpgrade = {
      enable = true;
      dates = "04:30";
      flake = "${repoPath}#nixos";
      allowReboot = false;
      flags = [
        "--refresh"
      ];
    };

    # 2. Flake Update Service (Runs before autoUpgrade)
    # This ensures the local flake.lock is updated so autoUpgrade has new versions to pull.
    systemd.services.nix-flake-update = {
      description = "Update Nix Flake Lockfile";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.nix pkgs.git pkgs.openssh ];
      script = ''
        cd ${repoPath}
        # Only update if it's a git repo and we have permissions
        if [ -d .git ]; then
          nix flake update --commit-lock-file
        else
          nix flake update
        fi
      '';
      startAt = "04:00"; # Run 30 mins before autoUpgrade
    };

    # 3. Podman Container Auto-Updates
    # Runs 'podman auto-update' to refresh containers with the 'io.containers.autoupdate' label.
    systemd.services.podman-auto-update = {
      description = "Podman Container Auto-Update";
      after = [ "network-online.target" "nixos-upgrade.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.podman}/bin/podman auto-update";
        ExecStartPost = "${pkgs.podman}/bin/podman image prune -f";
      };
    };

    systemd.timers.podman-auto-update = {
      description = "Podman Container Auto-Update Timer";
      timerConfig = {
        OnCalendar = "05:00";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    # Ensure the auto-upgrade service waits for the flake update
    systemd.services.nixos-upgrade.after = [ "nix-flake-update.service" ];
  };
}
