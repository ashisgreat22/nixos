{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.noctalia;

  # Catppuccin Mocha Palette
  mocha = {
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
    text = "#cdd6f4";
    subtext0 = "#a6adc8";
    overlay0 = "#6c7086";

    mauve = "#cba6f7"; # Primary
    lavender = "#b4befe"; # Secondary
    pink = "#f5c2e7"; # Tertiary
    red = "#f38ba8"; # Error
  };

in
{
  imports = [ inputs.noctalia.homeModules.default ];

  options.myModules.noctalia = {
    enable = lib.mkEnableOption "Noctalia Shell Configuration";
  };

  config = lib.mkIf cfg.enable {
    # Correct Option Name: programs.noctalia-shell
    programs.noctalia-shell = {
      enable = true;

      # Manual Catppuccin Mocha Theme mapping to Material Design roles
      colors = {
        mPrimary = mocha.mauve;
        mOnPrimary = mocha.base;

        mSecondary = mocha.lavender;
        mOnSecondary = mocha.base;

        mTertiary = mocha.pink;
        mOnTertiary = mocha.base;

        mError = mocha.red;
        mOnError = mocha.base;

        mSurface = mocha.base;
        mOnSurface = mocha.text;

        mSurfaceVariant = mocha.mantle;
        mOnSurfaceVariant = mocha.subtext0;

        mOutline = mocha.overlay0;
        mShadow = mocha.crust;
      };

      settings = {
        colorSchemes = {
          darkMode = true;
          useWallpaperColors = false; # Force our manual colors
        };
        location = {
          weatherEnabled = true;
          name = "Berlin";
        };
        wallpaper = {
          enabled = false;
        };
      };
    };
  };
}
