{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha";
    settings = {
      confirm_os_window_close = 0;
      cursor_shape = "beam";
    };
  };
}
