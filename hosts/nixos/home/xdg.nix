{ ... }:
{
  xdg.desktopEntries.youtube = {
    name = "YouTube";
    genericName = "Video sharing platform";
    exec = "brave --profile-directory=YouTube --app=https://youtube.com";
    terminal = false;
    categories = [
      "Network"
      "Video"
      "AudioVideo"
    ];
    icon = "youtube";
  };

  xdg.desktopEntries.steam = {
    name = "Steam";
    genericName = "Game Store";
    exec = "steam %U";
    terminal = false;
    categories = [ "Game" ];
    icon = "steam";
    mimeType = [
      "x-scheme-handler/steam"
      "x-scheme-handler/steamlink"
    ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [
        "onlyoffice-desktopeditors.desktop"
      ];
      "application/msword" = [ "onlyoffice-desktopeditors.desktop" ];
      "text/html" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/http" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/https" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/about" = [ "nix.bwrapper.firefox.desktop" ];
      "x-scheme-handler/unknown" = [ "nix.bwrapper.firefox.desktop" ];
      "application/xhtml+xml" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-htm" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-html" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-shtml" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-xhtml" = [ "nix.bwrapper.firefox.desktop" ];
      "application/x-extension-xht" = [ "nix.bwrapper.firefox.desktop" ];
      "application/pdf" = [ "nix.bwrapper.firefox.desktop" ];
    };
  };
}
