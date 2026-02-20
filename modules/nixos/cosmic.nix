{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.myModules.desktop.cosmic;
in
{
  options.myModules.desktop.cosmic = {
    enable = lib.mkEnableOption "Cosmic Desktop Environment";
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.cosmic.enable = true;
    services.displayManager.cosmic-greeter.enable = false;

    # Optimization
    services.system76-scheduler.enable = true;

    # Clipboard support (unstable protocol)
    environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";
  };
}