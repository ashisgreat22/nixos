{ ... }:
{
  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      serif = [ "ComicShannsMono Nerd Font" ];
      sansSerif = [ "ComicShannsMono Nerd Font" ];
      monospace = [ "ComicShannsMono Nerd Font Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
