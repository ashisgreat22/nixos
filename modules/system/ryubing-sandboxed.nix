{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  appId = "org.ryubing.Ryubing";
in
{
  nixpkgs.overlays = [
    (final: prev: {
      ryubing-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = pkgs.ryubing;
          id = appId;
          env = {
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            # Ryubing uses Avalonia which works better with X11
            AVALONIA_SCREEN_SCALE_FACTOR = "1";
          };
        };

        # Enable X11 and Wayland
        sockets.x11 = true;
        sockets.wayland = true;

        # Disable Flatpak emulation
        flatpak.enable = false;

        fhsenv.opts = {
          unshareUser = true;
          unshareUts = false;
          unshareCgroup = false;
          unsharePid = false;
          unshareNet = false; # Need network for online features
          unshareIpc = false;
        };

        fhsenv.bwrap.baseArgs = lib.mkForce [
          "--new-session"
          "--proc /proc"
          "--dev /dev"
          "--dev-bind /dev/dri /dev/dri" # GPU acceleration
          "--dev-bind /dev/shm /dev/shm" # Shared memory
          "--dev-bind-try /dev/uinput /dev/uinput" # Controller support
          "--dev-bind-try /dev/input /dev/input"
          "--tmpfs /home"
          "--tmpfs /tmp"
          "--tmpfs /run"
          "--dir /run/user"
          "--dir /run/user/${toString config.users.users.ashie.uid}"
          # Fix for amdgpu.ids missing - use tmpfs so mkdir can succeed
          "--tmpfs /usr/share"
          "--ro-bind ${pkgs.libdrm}/share/libdrm /usr/share/libdrm"
          # System paths
          "--ro-bind /sys /sys"
          "--ro-bind-try /run/current-system /run/current-system"
          "--ro-bind-try /run/opengl-driver /run/opengl-driver"
          "--ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32"
          "--ro-bind-try /nix/store /nix/store"
          "--dir /run/systemd/resolve"
          "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
          # udev for controller hotplug
          "--ro-bind-try /run/udev /run/udev"
        ];

        # Disable built-in DBus module (invokes bwrap without --unshare-user)
        dbus.enable = false;

        # Manually set up DBus proxy with --unshare-user (session bus only)
        # Also create required directories before bwrap runs
        script.preCmds.stage2 = ''
          # Create directories that bwrap will bind
          # Note: Ryubing still uses Ryujinx config paths
          mkdir -p "$HOME/.config/Ryujinx/system"
          mkdir -p "$HOME/.config/Ryujinx/bis/system/Contents/registered"
          mkdir -p "$HOME/.local/share/Ryujinx"
          mkdir -p "$HOME/Games/Switch"
        ''
        + (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          inherit appId;
          enableSystemBus = false;
          proxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.portal.Desktop"''
            ''--talk="org.freedesktop.portal.OpenURI"''
            ''--talk="org.freedesktop.portal.FileChooser"''
            ''--talk="org.freedesktop.portal.*"''
            ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
            ''--talk="org.freedesktop.Notifications"''
            ''--talk="org.freedesktop.ScreenSaver"''
            ''--talk="org.kde.StatusNotifierWatcher"''
            ''--talk="org.kde.KWin"''
            ''--talk="org.gnome.Mutter.DisplayConfig"''
            ''--talk="org.freedesktop.secrets"''

            ''--talk="com.feralinteractive.GameMode"''
            ''--own="${appId}"''
            ''--own="${appId}.*"''
          ];
        };

        fhsenv.bwrap.additionalArgs = [
          # D-Bus session proxy only
          ''--bind "$XDG_RUNTIME_DIR/app/${appId}/bus" "$XDG_RUNTIME_DIR/bus"''

          # Wayland socket
          ''--bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"''

          # PipeWire + Pulse
          ''--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"''
          ''--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"''

          # Manual mounts for data persistence
          "--ro-bind-try $HOME/.config/kdedefaults $HOME/.config/kdedefaults"
          "--ro-bind-try $HOME/.local/share/color-schemes $HOME/.local/share/color-schemes"
          "--ro-bind-try $HOME/.config/fontconfig $HOME/.config/fontconfig"
          "--ro-bind-try $HOME/.local/share/fonts $HOME/.local/share/fonts"
          "--ro-bind-try $HOME/.icons $HOME/.icons"
          "--ro-bind-try $HOME/.themes $HOME/.themes"
          "--ro-bind-try $HOME/.config/MangoHud $HOME/.config/MangoHud"
          # Read-write mounts
          "--bind $HOME/Games/Switch $HOME/Games/Switch"
          "--bind $HOME/.config/Ryujinx $HOME/.config/Ryujinx"
          "--bind $HOME/.local/share/Ryujinx $HOME/.local/share/Ryujinx"
        ];
      };
    })
  ];
}
