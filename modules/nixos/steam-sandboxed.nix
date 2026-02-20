# Steam Sandboxed with nix-bwrapper
# Provides a sandboxed Steam with restricted permissions like Lutris
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };
in
sandboxUtils.mkSandboxedApp {
  inherit
    config
    lib
    pkgs
    inputs
    ;
  optionName = "steamSandboxed";
  packageName = "steam-sandboxed";
  description = "sandboxed Steam with nix-bwrapper";
  package = pkgs.steam;
  appId = "com.valvesoftware.Steam";
  isFhsenv = true;

  env = {
    XDG_DATA_DIRS = "$XDG_DATA_DIRS";
    PROTON_USE_NTSYNC = 1;
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    DBUS_SESSION_BUS_ADDRESS = "unix:path=$XDG_RUNTIME_DIR/bus";
  };

  fhsenvExtra = {
    skipExtraInstallCmds = true;
  };

  fhsenvOpts = {
    unshareUser = true;
    unshareUts = false;
    unshareCgroup = false;
    unsharePid = false;
    unshareNet = false;
    unshareIpc = false;
  };

  baseArgs =
    sandboxUtils.mkCommonBindArgs { inherit config lib; } ++ sandboxUtils.mkGamingBindArgs { };

  mounts = {
    read = [ ];
    readWrite = [
      "$HOME/.steam"
      "$HOME/.local/share/Steam"
      "$HOME/.local/share/umu"
      "$HOME/.local/share/applications"
      "$HOME/.local/share/desktop-directories"
      "$HOME/.local/share/icons"
      "$HOME/.local/share/Larian Studios"
      "$HOME/Desktop"
      "/games/steam"
      "/games/windows/Modlist"
      "/games/windows/Modlist_Downloads"
    ];
  };

  dbusProxy = {
    enable = true;
    enableSystemBus = false;
    rules = [
      "--filter"
      ''--talk="org.freedesktop.portal.*"''
      ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
      ''--talk="org.freedesktop.Notifications"''
      ''--talk="org.freedesktop.ScreenSaver"''
      ''--talk="org.kde.StatusNotifierWatcher"''
      ''--talk="org.kde.KWin"''
      ''--talk="org.gnome.Mutter.DisplayConfig"''
      ''--talk="org.freedesktop.secrets"''
      ''--talk="com.feralinteractive.GameMode"''
      ''--talk="org.freedesktop.portal.*"''
      ''--own="com.valvesoftware.Steam"''
      ''--own="com.valvesoftware.Steam.*"''
      ''--own="com.steampowered.PressureVessel.*"''
    ];
  };
}
