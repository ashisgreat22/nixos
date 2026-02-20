# Spotify Sandboxed with nix-bwrapper
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.spotifySandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };
in
{
  options.myModules.spotifySandboxed = {
    enable = lib.mkEnableOption "sandboxed Spotify with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        spotify-sandboxed = bwrapperPkgs.mkBwrapper {
          app = {
            package = prev.spotify;
            id = "com.spotify.Client";
            env = {
              # Propagate XDG_DATA_DIRS for theming
              XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            };
          };

          # Enable X11 and Wayland
          sockets.x11 = true;
          sockets.wayland = true;

          # Spotify is not a flatpak ref, so disable flatpak emulation
          flatpak.enable = false;

          fhsenv.opts = {
            unshareUser = true;
            unshareUts = false;
            unshareCgroup = false;
            unsharePid = false;
            unshareNet = false; # Need network for streaming
            unshareIpc = false;
          };

          fhsenv.bwrap.baseArgs = lib.mkForce (sandboxUtils.mkCommonBindArgs { inherit config lib; } ++ sandboxUtils.mkGamingBindArgs { } ++ [
            # Audio
            "--ro-bind-try /etc/asound.conf /etc/asound.conf"
          ]);

          mounts = {
            read = sandboxUtils.mkGuiMounts.read;
            readWrite = [
              "$HOME/.config/spotify"
              "$HOME/.cache/spotify"
              "$HOME/.local/share/spotify"
            ] ++ cfg.extraBindMounts;
          };

          # Disable built-in DBus module (invokes bwrap without --unshare-user)
          dbus.enable = false;

          # Manually set up DBus proxy with --unshare-user (session bus only)
          script.preCmds.stage2 = sandboxUtils.mkDbusProxyScript {
            appId = "com.spotify.Client";
            enableSystemBus = false;
            proxyArgs = [
              "--filter"
              ''--talk="org.freedesktop.portal.*"''
              ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
              ''--talk="org.freedesktop.Notifications"''
              ''--talk="org.freedesktop.ScreenSaver"''
              ''--talk="org.kde.StatusNotifierWatcher"''
              ''--talk="org.gnome.Mutter.DisplayConfig"''
              ''--talk="org.mpris.MediaPlayer2.Player"''
              ''--own="org.mpris.MediaPlayer2.spotify"''
              ''--own="com.spotify.Client"''
              ''--own="com.spotify.Client.*"''
            ];
          };

          fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
            # D-Bus session proxy only
            ''--bind "$XDG_RUNTIME_DIR/app/com.spotify.Client/bus" "$XDG_RUNTIME_DIR/bus"''
          ];
        };
      })
    ];

    environment.systemPackages = [ pkgs.spotify-sandboxed ];
  };
}
