# Security Hardening Module
# Provides: doas (sudo replacement), audit logging, AppArmor, core dump prevention
#
# Usage:
#   myModules.security = {
#     enable = true;
#     enableAudit = true;      # default: true
#     enableAppArmor = true;   # default: true
#     useDoas = true;          # default: true (replaces sudo)
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.security;
in
{
  options.myModules.security = {
    enable = lib.mkEnableOption "security hardening module";

    useDoas = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Replace sudo with doas for privilege escalation";
    };

    enableAudit = lib.mkOption {
      type = lib.types.bool;
      default = false; # Disabled: still incompatible with kernel
      description = "Enable auditd with security-focused rules";
    };

    enableAppArmor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable AppArmor mandatory access control";
    };

    enableFail2Ban = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Fail2Ban for SSH and other services";
    };

    wheelGroup = lib.mkOption {
      type = lib.types.str;
      default = "wheel";
      description = "Group allowed to use doas/sudo";
    };
  };

  config = lib.mkIf cfg.enable {
    # Replace sudo with doas
    security.sudo.enable = !cfg.useDoas;
    security.doas.enable = cfg.useDoas;
    security.doas.extraRules = lib.mkIf cfg.useDoas [
      {
        groups = [ cfg.wheelGroup ];
        keepEnv = false;
        persist = true;
      }
    ];

    # Security audit logging
    security.auditd.enable = cfg.enableAudit;
    security.audit = lib.mkIf cfg.enableAudit {
      enable = true;
      rules = [
        # Log all execve calls (command execution)
        "-a exit,always -F arch=b64 -S execve"
        # Log privilege escalation
        "-w /etc/shadow -p wa -k shadow"
        "-w /etc/passwd -p wa -k passwd"
        "-w /etc/group -p wa -k group"
        # Watch for kernel module insertion
        "-a always,exit -F arch=b64 -S init_module -S finit_module -k module_insertion"
      ];
    };

    # Disable core dumps
    systemd.coredump.enable = false;

    # AppArmor
    security.apparmor = lib.mkIf cfg.enableAppArmor {
      enable = true;
      packages = with pkgs; [ apparmor-profiles ];
    };

    # Polkit for privilege management
    security.polkit.enable = true;

    # Restrict su to wheel group
    security.pam.services.su.requireWheel = true;

    # Fail2Ban
    services.fail2ban = lib.mkIf cfg.enableFail2Ban {
      enable = true;
      maxretry = 5;
      bantime = "24h"; # Ban for 24 hours
      bantime-increment = {
        enable = true; # Enable exponential backoff
        factor = "2";
        maxtime = "168h"; # Max ban time of 1 week
      };
      ignoreIP = [
        "127.0.0.1/8"
        "10.0.0.0/8"
        "192.168.0.0/16"
      ];
    };
  };
}
