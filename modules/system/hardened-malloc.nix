# Hardened Malloc Module (Scudo)
# Provides: Userspace memory corruption mitigations via LLVM Scudo
#
# Usage:
#   myModules.hardenedMalloc = {
#     enable = true;
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.hardenedMalloc;
in
{
  options.myModules.hardenedMalloc = {
    enable = lib.mkEnableOption "hardened memory allocator (Scudo)";
  };

  config = lib.mkIf cfg.enable {
    environment.memoryAllocator.provider = "scudo";
    
    # Scudo options:
    # ZeroContents=1: Zero chunks on allocation/deallocation (mitigates use-after-free info leaks)
    # PatternFillContents=1: (Alternative to Zero) Fill with pattern to catch bugs
    environment.variables.SCUDO_OPTIONS = "ZeroContents=1";
  };
}
