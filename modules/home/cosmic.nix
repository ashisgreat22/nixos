{
  # programs.cosmic-manager.enable = true; # Deprecated
  # Add cosmic-manager configurations here
  # Example:
  # programs.cosmic-edit.enable = true;

  xdg.configFile."cosmic/com.system76.CosmicComp/v1/input_default".text = ''
    (
      acceleration_profile: Flat,
    )
  '';
}
