# Spotify Sandboxed with nix-bwrapper
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      spotify-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = prev.spotify;
          id = "com.spotify.Client";
          env = {
            # Propagate XDG_DATA_DIRS for theming
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            # Force Wayland if preferred, or rely on auto-detection
            # DISPLAY variable is handled by sockets.x11/wayland
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

        fhsenv.bwrap.baseArgs = lib.mkForce [
          "--new-session"
          "--proc /proc"
          "--dev /dev"
          "--dev-bind /dev/dri /dev/dri" # GPU acceleration
          "--tmpfs /home"
          "--tmpfs /tmp"
          "--tmpfs /run"
          "--dir /run/user"
          "--dir /run/user/${toString config.users.users.ashie.uid}"
          # System paths
          "--ro-bind /sys /sys"
          "--ro-bind-try /run/current-system /run/current-system"
          "--ro-bind-try /run/opengl-driver /run/opengl-driver"
          "--ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32"
          "--dir /run/systemd/resolve"
          "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
          # Audio
          "--ro-bind-try /etc/asound.conf /etc/asound.conf"
        ];

        mounts = {
          read = [
            "$HOME/.config/fontconfig"
            "$HOME/.local/share/fonts"
            "$HOME/.icons"
            "$HOME/.themes"
            "$HOME/.local/share/themes"
            "$HOME/.config/kdedefaults"
            "$HOME/.local/share/color-schemes"
          ];
          readWrite = [
            "$HOME/.config/spotify"
            "$HOME/.cache/spotify"
            "$HOME/.local/share/spotify"
          ];
        };

        # Disable built-in DBus module (invokes bwrap without --unshare-user)
        dbus.enable = false;

        # Manually set up DBus proxy with --unshare-user (session bus only)
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
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

        fhsenv.bwrap.additionalArgs = [
          # D-Bus session proxy only
          ''--bind "$XDG_RUNTIME_DIR/app/com.spotify.Client/bus" "$XDG_RUNTIME_DIR/bus"''

          # Wayland socket
          ''--bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"''

          # PipeWire + Pulse
          ''--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"''
          ''--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"''
        ];
      };
    })
  ];
}
