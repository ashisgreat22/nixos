# Faugus Launcher Sandboxed with nix-bwrapper
# Provides a sandboxed Faugus Launcher with restricted permissions
# Uses advanced D-Bus proxy approach like Steam for stronger isolation
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.faugusSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };
in
{
  options.myModules.faugusSandboxed = {
    enable = lib.mkEnableOption "sandboxed Faugus Launcher with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        faugus-sandboxed =
          let
            singleDesktopPkg =
              pkgs.symlinkJoin {
                name = "faugus-launcher-single";
                paths = [ prev.faugus-launcher ];
                postBuild = ''
                  rm -rf $out/share/applications
                  mkdir -p $out/share/applications
                  ln -s ${prev.faugus-launcher}/share/applications/faugus-launcher.desktop $out/share/applications/io.github.faugus.Launcher.desktop
                '';
              }
              // {
                inherit (prev.faugus-launcher) pname version meta;
              };
          in
          bwrapperPkgs.mkBwrapper {
            app = {
              package = singleDesktopPkg;
              id = "io.github.faugus.Launcher";
              env = {
                # Propagate XDG_DATA_DIRS so themes/icons can be found
                XDG_DATA_DIRS = "$XDG_DATA_DIRS";
                # Fix for file dialogs/theming
                XDG_CURRENT_DESKTOP = "KDE";
                # GTK theming
                GTK_THEME = "catppuccin-frappe-blue-standard";
                # Force GTK to use the portal for file dialogs
                GTK_USE_PORTAL = "1";
                # Force Wayland backend to ensure xdg-foreign protocol works
                GDK_BACKEND = "wayland";
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
              unshareNet = false; # Need network
              unshareIpc = false;
            };

            fhsenv.bwrap.baseArgs = lib.mkForce (sandboxUtils.mkCommonBindArgs { inherit config lib; } ++ sandboxUtils.mkGamingBindArgs { });

            mounts = {
              read = sandboxUtils.mkGuiMounts.read ++ [
                "$HOME/.gtkrc-2.0"
              ];
              readWrite = [
                "$HOME/Games"
                "$HOME/.config/faugus-launcher"
                "$HOME/.local/share/faugus-launcher"
                "$HOME/.cache/faugus-launcher"
                "$HOME/.config/qt6ct" # Allow theming
              ] ++ cfg.extraBindMounts;
            };

            # Disable built-in DBus module (invokes bwrap without --unshare-user)
            dbus.enable = false;

            # Manually set up DBus proxy with --unshare-user (session bus only)
            script.preCmds.stage2 = sandboxUtils.mkDbusProxyScript {
              appId = "io.github.faugus.Launcher";
              enableSystemBus = false; # No system bus access
              proxyArgs = [
                "--filter"
                ''--talk="org.freedesktop.portal.*"''
                ''--talk="org.freedesktop.portal.FileChooser"''
                ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
                ''--talk="org.freedesktop.Notifications"''
                ''--talk="org.freedesktop.ScreenSaver"''
                ''--talk="org.kde.StatusNotifierWatcher"''
                ''--talk="org.kde.KWin"''
                ''--talk="org.gnome.Mutter.DisplayConfig"''
                ''--talk="org.freedesktop.secrets"''
                ''--talk="org.freedesktop.portal.Settings"''
                ''--talk="com.feralinteractive.GameMode"''
                ''--own="io.github.faugus.Launcher"''
                ''--own="io.github.faugus.Launcher.*"''
              ];
            };

            fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
              # D-Bus session proxy only
              ''--bind "$XDG_RUNTIME_DIR/app/io.github.faugus.Launcher/bus" "$XDG_RUNTIME_DIR/bus"''

              # dconf for GTK settings
              "--bind-try /run/user/${toString config.users.users.${config.myModules.system.mainUser}.uid}/dconf /run/user/${toString config.users.users.${config.myModules.system.mainUser}.uid}/dconf"
            ];
          };
      })
    ];

    environment.systemPackages = [ pkgs.faugus-sandboxed ];
  };
}
