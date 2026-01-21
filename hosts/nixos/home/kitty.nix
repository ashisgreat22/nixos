{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha"; # Updated option name
    settings = {
      confirm_os_window_close = 0;
      cursor_shape = "beam";
    };

    # extraConfig = ''
    #    include current-theme.conf
    #  '';
  };
}
