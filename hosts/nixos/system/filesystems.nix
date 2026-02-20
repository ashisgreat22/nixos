{ lib, ... }:
{
  # FORCE Root Filesystem to satisfy assertions
  fileSystems."/" = lib.mkForce {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=16G"
      "mode=755"
    ];
  };
}
