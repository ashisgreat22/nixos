{
  lib,
  config,
  ...
}:
{
  options.myModules.common = {
    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/nixos";
      description = "Path to the main NixOS configuration repository";
    };
  };
}
