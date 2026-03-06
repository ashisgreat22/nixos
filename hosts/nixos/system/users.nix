{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.fish.enable = true;

  users.mutableUsers = false;

  users.users.ashie = {
    isNormalUser = true;
    linger = true;
    # initialPassword = "password"; # Temporary password, change with 'passwd' after login
    hashedPasswordFile = config.sops.secrets.hashed_password.path;
    uid = 1000;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "podman"
      "render"
      "video"
      "media"
    ];
    packages = with pkgs; [
      tree
    ];
    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
      {
        startUid = 200000000;
        count = 100000000;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
      {
        startGid = 200000000;
        count = 100000000;
      }
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrff2OCTbuThkfOYQmf4T+pbA+rk4tGodk7HsXf30rN u0_a337@localhost"
    ];
  };


  users.groups.media = { };

  # Disable root password login
  users.users.root = {
    hashedPassword = "!";
    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
    ];
  };

  # Restrict su to wheel group
  security.pam.services.su.requireWheel = true;

  # Alias sudo to doas for muscle memory
  environment.shellAliases = {
    sudo = "doas";
  };

  # System user for Podman --userns=auto allocations
  users.users.containers = {
    isSystemUser = true;
    group = "containers";
    subUidRanges = [
      {
        startUid = 200000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 200000;
        count = 65536;
      }
    ];
  };
  users.groups.containers = { };
}
