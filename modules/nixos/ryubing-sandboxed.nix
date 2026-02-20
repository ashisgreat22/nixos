{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.ryubingSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };

  appId = "org.ryubing.Ryubing";
in
{
  options.myModules.ryubingSandboxed = {
    enable = lib.mkEnableOption "sandboxed Ryubing with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
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
            # Note: Ryubing still uses Ryujinx config paths
            mkdir -p "$HOME/.config/Ryujinx/system"
            mkdir -p "$HOME/.config/Ryujinx/bis/system/Contents/registered"
            mkdir -p "$HOME/.local/share/Ryujinx"
            mkdir -p "$HOME/Games/Switch"
          ''
          + sandboxUtils.mkDbusProxyScript {
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

          fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
            # D-Bus session proxy only
            ''--bind "$XDG_RUNTIME_DIR/app/${appId}/bus" "$XDG_RUNTIME_DIR/bus"''

            # Read-write mounts
            "--bind $HOME/Games/Switch $HOME/Games/Switch"
            "--bind $HOME/.config/Ryujinx $HOME/.config/Ryujinx"
            "--bind $HOME/.local/share/Ryujinx $HOME/.local/share/Ryujinx"
          ];

          mounts = {
            read = sandboxUtils.mkGuiMounts.read;
            readWrite = cfg.extraBindMounts;
          };
        };
      })
    ];

    environment.systemPackages = [ pkgs.ryubing-sandboxed ];
  };
}
