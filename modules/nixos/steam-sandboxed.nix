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
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      steam-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = prev.steam;
          isFhsenv = true; # Steam uses buildFHSEnv
          id = "com.valvesoftware.Steam";
          env = {
            # Unset LD_PRELOAD to avoid mimalloc crashes
            LD_PRELOAD = "";
            # Propagate XDG_DATA_DIRS for theming
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            # Proton/Wine optimizations
            PROTON_USE_NTSYNC = 1;
            XDG_CURRENT_DESKTOP = "niri";
            XDG_SESSION_TYPE = "wayland";
            DBUS_SESSION_BUS_ADDRESS = "unix:path=$XDG_RUNTIME_DIR/bus";
          };
        };

        # Enable X11 and Wayland
        sockets.x11 = true;
        sockets.wayland = true;

        # Disable Flatpak emulation
        flatpak.enable = false;

        fhsenv = {
          skipExtraInstallCmds = true; # Steam package is special, don't try to modify it
        };

        fhsenv.opts = {
          unshareUser = true;
          unshareUts = false;
          unshareCgroup = false;
          unsharePid = false; # Share PIDs for compatibility
          unshareNet = false; # Need network for Steam login/downloads
          unshareIpc = false;
        };

        fhsenv.bwrap.baseArgs = lib.mkForce [
          "--new-session"
          "--proc /proc"
          "--dev /dev"
          "--dev-bind /dev/dri /dev/dri" # GPU acceleration
          "--dev-bind /dev/shm /dev/shm" # Shared memory (required for games)
          "--dev-bind-try /dev/uinput /dev/uinput" # Controller support
          "--dev-bind-try /dev/input /dev/input" # Controller/input devices
          "--dev-bind-try /dev/hidraw0 /dev/hidraw0" # HID devices (controllers)
          "--dev-bind-try /dev/hidraw1 /dev/hidraw1"
          "--dev-bind-try /dev/hidraw2 /dev/hidraw2"
          "--dev-bind-try /dev/hidraw3 /dev/hidraw3"
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
          "--unsetenv LD_PRELOAD"
          # udev for controller hotplug
          "--ro-bind-try /run/udev /run/udev"
        ];

        mounts = {
          read = [
            "$HOME/.config/fontconfig"
            "$HOME/.local/share/fonts"
            "$HOME/.icons"
            "$HOME/.themes"
            "$HOME/.local/share/themes"
            "$HOME/.config/qt6ct"
            "$HOME/.config/Kvantum"
            "$HOME/.config/MangoHud"
            "$HOME/.config/kdedefaults"
            "$HOME/.local/share/color-schemes"
          ];
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
          ];
        };

        # Disable built-in DBus module (invokes bwrap without --unshare-user)
        dbus.enable = false;

        # Manually set up DBus proxy with --unshare-user (session bus only)
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          appId = "com.valvesoftware.Steam";
          enableSystemBus = false; # No system bus access
          proxyArgs = [
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

        fhsenv.bwrap.additionalArgs = [
          # D-Bus session proxy only
          ''--bind "$XDG_RUNTIME_DIR/app/com.valvesoftware.Steam/bus" "$XDG_RUNTIME_DIR/bus"''

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
