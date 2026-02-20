{
  lib,
  config,
  ...
}:
{
  options.myModules.system = {
    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashie/nixos";
      description = "Path to the main NixOS configuration repository";
    };

    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "ashie";
      description = "Username of the main user";
    };
  };
}
