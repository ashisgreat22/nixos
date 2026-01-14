{ pkgs, ... }:
{
  programs.mangohud = {
    enable = true;
    settings = {
      # Performance overlay
      fps = true;
      frametime = false;
      frame_timing = false;
      histogram = false;

      # Hardware stats (Ensure disabled)
      cpu_stats = false;
      gpu_stats = false;
      ram = false;
      vram = false;
      core_load = false;
      gpu_load = false;

      # Appearance
      legacy_layout = false;
      table_columns = 3;
      background_alpha = 0.0;
      font_size = 24;
      position = "top-left";
      round_corners = 10;
    };
  };
}
