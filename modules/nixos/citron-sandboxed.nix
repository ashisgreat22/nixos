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
  cfg = config.myModules.citronSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };

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
  options.myModules.citronSandboxed = {
    enable = lib.mkEnableOption "sandboxed Citron with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
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

          fhsenv.bwrap.baseArgs = lib.mkForce (sandboxUtils.mkCommonBindArgs { inherit config lib; } ++ sandboxUtils.mkGamingBindArgs { } ++ [
            # Fix for amdgpu.ids missing - use tmpfs so mkdir can succeed
            "--tmpfs /usr/share"
            "--ro-bind ${pkgs.libdrm}/share/libdrm /usr/share/libdrm"
            "--ro-bind-try /nix/store /nix/store"
          ]);

          # Disable built-in DBus module (invokes bwrap without --unshare-user)
          dbus.enable = false;

          # Manually set up DBus proxy with --unshare-user (session bus only)
          # Also create required directories before bwrap runs
          script.preCmds.stage2 = ''
            # Create directories that bwrap will bind
            mkdir -p "$HOME/.cache/citron-tmp"
            mkdir -p "$HOME/.config/citron"
            mkdir -p "$HOME/.config/Citron"
            mkdir -p "$HOME/.local/share/citron"
            mkdir -p "$HOME/.local/share/Citron"
            mkdir -p "$HOME/Games/Switch"
          ''
          + sandboxUtils.mkDbusProxyScript {
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

          fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
            # D-Bus session proxy only
            ''--bind "$XDG_RUNTIME_DIR/app/${appId}/bus" "$XDG_RUNTIME_DIR/bus"''

            # Read-write mounts
            "--bind $HOME/Games/Switch $HOME/Games/Switch"
            "--bind $HOME/.config/citron $HOME/.config/citron"
            "--bind $HOME/.config/Citron $HOME/.config/Citron"
            "--bind $HOME/.local/share/citron $HOME/.local/share/citron"
            "--bind $HOME/.local/share/Citron $HOME/.local/share/Citron"
            "--bind $HOME/.cache/citron-tmp $HOME/.cache/citron-tmp"
          ];

          mounts = {
            read = sandboxUtils.mkGuiMounts.read;
            readWrite = cfg.extraBindMounts;
          };
        };
      })
    ];

    environment.systemPackages = [ pkgs.citron-sandboxed ];
  };
}
