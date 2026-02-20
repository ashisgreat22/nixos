{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.firefoxSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };

  firefoxPolicies = pkgs.writeText "policies.json" (
    builtins.toJSON {
      policies = {
        Preferences = {
          "xpinstall.signatures.required" = false;
        };
      };
    }
  );
in
{
  options.myModules.firefoxSandboxed = {
    enable = lib.mkEnableOption "sandboxed Firefox with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        firefox-sandboxed = bwrapperPkgs.mkBwrapper {
          app = {
            package = prev.firefox-esr;
            # Omit app.id to avoid document portal bind that fails on FUSE
            env = {
              MOZ_ENABLE_WAYLAND = "1";
              LD_PRELOAD = "";
              # Propagate XDG_DATA_DIRS so GTK can find themes in user profile/system
              XDG_DATA_DIRS = "$XDG_DATA_DIRS";
              GTK_THEME = "catppuccin-mocha-mauve-standard";
              HYPRCURSOR_THEME = "Future-Cyan-Hyprcursor_Theme";
              HYPRCURSOR_SIZE = "32";
            };
          };

          flatpak.enable = false;
          sockets.x11 = false;
          sockets.wayland = true;
          fhsenv.opts = {
            unshareUser = true;
            unshareUts = false;
            unshareCgroup = false;
            unsharePid = false;
            unshareNet = false;
            unshareIpc = false;
          };

          fhsenv.bwrap.baseArgs = lib.mkForce (
            sandboxUtils.mkCommonBindArgs { inherit config lib; }
            ++ sandboxUtils.mkGamingBindArgs { }
            ++ [
              "--tmpfs /mnt"
              "--ro-bind-try /run/booted-system /run/booted-system"
              "--setenv MOZ_ENABLE_WAYLAND \"1\""
              "--setenv NOTIFY_IGNORE_PORTAL 1"
              "--dir /etc"
              "--dir /etc/firefox"
              "--dir /etc/firefox/policies"
              "--ro-bind ${firefoxPolicies} /etc/firefox/policies/policies.json"
            ]
          );

          # Filesystem: Limited to Mozilla directories and Downloads
          mounts = {
            read = sandboxUtils.mkGuiMounts.read ++ [
              "$HOME/.config/user-dirs.dirs"
              "$HOME/.config/mimeapps.list"
            ];
            readWrite = [
              "$HOME/.mozilla"
              "$HOME/.cache/mozilla"
              "$HOME/Downloads"
            ]
            ++ cfg.extraBindMounts;
          };

          # Bind mount systemd-resolved socket for DNS and required system files
          # Disable built-in DBus module because it invokes bwrap without --unshare-user
          dbus.enable = false;

          # Manually set up DBus proxy with --unshare-user
          script.preCmds.stage2 = sandboxUtils.mkDbusProxyScript {
            appId = "nix.bwrapper.firefox";
            proxyArgs = [
              "--filter"
              ''--talk="org.freedesktop.portal.Desktop"''
              ''--talk="org.freedesktop.portal.OpenURI"''
              ''--talk="org.freedesktop.portal.FileChooser"''
              ''--talk="org.freedesktop.secrets"''
              ''--talk="org.kde.StatusNotifierWatcher"''
              ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
              ''--own="org.mozilla.firefox"''
              ''--own="org.mozilla.firefox.*"''
              ''--own="org.mpris.MediaPlayer2.firefox.*"''
            ];
            enableSystemBus = true;
            systemProxyArgs = [
              "--filter"
              ''--talk="org.freedesktop.NetworkManager"''
            ];
          };

          fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
            ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.firefox/bus" "$XDG_RUNTIME_DIR/bus"''
            ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.firefox/bus_system" /run/dbus/system_bus_socket''
            "--bind-try /run/user/${
              toString config.users.users.${config.myModules.system.mainUser}.uid
            }/dconf /run/user/${toString config.users.users.${config.myModules.system.mainUser}.uid}/dconf"
          ];
        };
      })
    ];

    environment.systemPackages = [ pkgs.firefox-sandboxed ];
  };
}
