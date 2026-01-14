# Citron Emulator Sandboxed with nix-bwrapper
# Runs AppImage directly (self-extracting) since pkgforge uses non-standard compression
# Uses manual DBus proxy approach like Steam/Faugus for stronger isolation
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  pname = "citron";
  version = "0.12.25";
  appId = "org.citron_emu.citron";

  citronAppImage = pkgs.fetchurl {
    url = "https://github.com/pkgforge-dev/Citron-AppImage/releases/download/0.12.25%402025-12-26_1766769485/Citron-0.12.25-anylinux-x86_64.AppImage";
    sha256 = "sha256-BLTX4IZX5BNt7NlUti8NILL76NCzsPShkvx8BS/pl38=";
  };

  # Create a wrapper script that runs the AppImage directly
  # AppImages are self-extracting executables
  citronWrapper = pkgs.writeShellScriptBin "citron" ''
    # Ensure the AppImage can extract to a writable location
    export APPIMAGE_EXTRACT_AND_RUN=1
    export TMPDIR="$HOME/.cache/citron-tmp"
    mkdir -p "$TMPDIR"

    # Copy AppImage to cache and make executable if needed

    # Use a unique name based on the hash to avoid busy-file issues
    # Sanitize hash to remove slashes which break paths
    APPIMAGE_HASH=$(echo "${citronAppImage.outputHash}" | tr '/' '_')
    APPIMAGE="$TMPDIR/citron-$APPIMAGE_HASH.AppImage"

    if [ ! -f "$APPIMAGE" ]; then
       # Clean up old versions
       rm -f "$TMPDIR"/citron-*.AppImage
       cp "${citronAppImage}" "$APPIMAGE"
       chmod 755 "$APPIMAGE"
    fi
    exec "$APPIMAGE" "$@"
  '';

  # Final package with proper attributes
  citron =
    pkgs.symlinkJoin {
      name = "${pname}-${version}";
      paths = [ citronWrapper ];
      postBuild = ''
        mkdir -p $out/share/applications
        cat > $out/share/applications/${appId}.desktop << EOF
        [Desktop Entry]
        Type=Application
        Name=Citron
        Comment=Nintendo Switch Emulator
        Exec=citron
        Icon=citron
        Terminal=false
        Categories=Game;Emulator;
        EOF
      '';
    }
    // {
      inherit pname version;
      meta = {
        description = "Nintendo Switch Emulator";
        homepage = "https://citron-emu.org/";
        mainProgram = "citron";
      };
    };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      citron-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = citron;
          id = appId;
          env = {
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            QT_QPA_PLATFORM = "wayland;xcb";
            XDG_CURRENT_DESKTOP = "KDE";
            # Allow AppImage to extract and run
            APPIMAGE_EXTRACT_AND_RUN = "1";
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
          mkdir -p "$HOME/.cache/citron-tmp"
          mkdir -p "$HOME/.config/citron"
          mkdir -p "$HOME/.local/share/citron"
          mkdir -p "$HOME/Games/Switch"
        ''
        + (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          inherit appId;
          enableSystemBus = false;
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
          "--ro-bind-try $HOME/.config/qt6ct $HOME/.config/qt6ct"
          "--ro-bind-try $HOME/.config/Kvantum $HOME/.config/Kvantum"
          "--ro-bind-try $HOME/.config/MangoHud $HOME/.config/MangoHud"
          # Read-write mounts
          "--bind $HOME/Games/Switch $HOME/Games/Switch"
          "--bind $HOME/.config/citron $HOME/.config/citron"
          "--bind $HOME/.local/share/citron $HOME/.local/share/citron"
          "--bind $HOME/.cache/citron-tmp $HOME/.cache/citron-tmp"
        ];
      };
    })
  ];
}
