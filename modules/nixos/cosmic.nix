{
  pkgs,
  ...
}:
{
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = false;

  # Optimization
  services.system76-scheduler.enable = true;

  # Clipboard support (unstable protocol)
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";
}
