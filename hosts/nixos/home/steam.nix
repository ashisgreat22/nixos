{
  config,
  pkgs,
  inputs,
  ...
}:
{
  programs.steam.config = {
    enable = true;
    closeSteam = true; # Closes Steam on rebuild, to prevent data loss
    defaultCompatTool = "proton-cachyos-latest";

    apps = {
      overwatch2 = {
        id = 2357570;
        compatTool = "proton-cachyos-latest";
        launchOptions = "gamemoderun mangohud PROTON_USE_NTSYNC=1 ENABLE_LAYER_MESA_ANTI_LAG=1 PROTON_LOCAL_SHADER_CACHE=1 %command%";
      };
    };
  };

  # Override Steam desktop entry to use bypass
  xdg.desktopEntries.steam = {
    name = "Steam";
    genericName = "Application Store";
    exec = "game-bypass steam %U";
    terminal = false;
    icon = "steam";
    categories = [
      "Network"
      "FileTransfer"
      "Game"
    ];
    mimeType = [
      "x-scheme-handler/steam"
      "x-scheme-handler/steamlink"
    ];
    prefetchIface = "steam";
  };
}
