{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  # create a custom settings.ini to force dark mode
  darkSettingsIni = pkgs.writeText "settings.ini" ''
    [Settings]
    gtk-theme-name=catppuccin-mocha-mauve-standard
    gtk-application-prefer-dark-theme=1
    gtk-cursor-theme-name=Future-Cyan-Hyprcursor_Theme
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintslight
    gtk-xft-rgba=rgb
  '';

  # Define policies.json with Catppuccin Theme and P-Stream extension
  firefoxPolicies = pkgs.writeText "policies.json" (
    builtins.toJSON {
      policies = {
        ExtensionSettings = {
          # Catppuccin Mocha Mauve (Official)
          "catppuccin-mocha-mauve-official@catppuccin.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/catppuccin-mocha-mauve-official/latest.xpi";
            installation_mode = "force_installed";
          };
          # P-Stream extension
          "{de055456-589b-45fe-8342-c685a7ffb424}" = {
            install_url = "https://github.com/p-stream/extension/releases/download/1.3.5/firefox-mv3-prod.xpi";
            installation_mode = "force_installed";
          };
        };
        Preferences = {
          "extensions.activeThemeID" = "catppuccin-mocha-mauve-official@catppuccin.com";
          "xpinstall.signatures.required" = false;
        };
      };
    }
  );
in
{
  nixpkgs.overlays = [
    (final: prev: {
      firefox-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = prev.firefox;
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

        fhsenv.bwrap.baseArgs = lib.mkForce [
          "--new-session"
          "--proc /proc"
          "--dev /dev"
          "--dev-bind /dev/dri /dev/dri"
          "--tmpfs /home"
          "--tmpfs /mnt"
          "--tmpfs /run"
          "--ro-bind-try /run/current-system /run/current-system"
          "--ro-bind-try /run/booted-system /run/booted-system"
          "--ro-bind-try /run/opengl-driver /run/opengl-driver"
          "--ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32"
          # Removed: --bind "$XDG_RUNTIME_DIR/doc/by-app/..." which causes FUSE errors
          "--unsetenv LD_PRELOAD"
          "--setenv MOZ_ENABLE_WAYLAND \"1\""
          "--setenv NOTIFY_IGNORE_PORTAL 1"
          "--dir /etc"
          "--dir /etc/firefox"
          "--dir /etc/firefox/policies"
          "--ro-bind ${firefoxPolicies} /etc/firefox/policies/policies.json"
        ];

        # Filesystem: Limited to Mozilla directories and Downloads
        mounts = {
          read = [
            "$HOME/.config/kdedefaults"
            "$HOME/.config/fontconfig"
            "$HOME/.config/user-dirs.dirs"
            "$HOME/.config/mimeapps.list"
            "$HOME/.local/share/color-schemes"
            "$HOME/.local/share/fonts"
            "$HOME/.icons"
            "$HOME/.themes"
            "$HOME/.local/share/themes"
            "$HOME/.config/gtk-3.0"
          ];
          readWrite = [
            "$HOME/.mozilla"
            "$HOME/.cache/mozilla"
            "$HOME/Downloads"
          ];
        };

        # Bind mount systemd-resolved socket for DNS and required system files
        # Disable built-in DBus module because it invokes bwrap without --unshare-user
        dbus.enable = false;

        # Manually set up DBus proxy with --unshare-user
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
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

        fhsenv.bwrap.additionalArgs = [
          ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.firefox/bus" "$XDG_RUNTIME_DIR/bus"''
          ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.firefox/bus_system" /run/dbus/system_bus_socket''
          "--dir /run/systemd/resolve"
          "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
          "--bind-try /run/user/${toString config.users.users.ashie.uid}/dconf /run/user/${toString config.users.users.ashie.uid}/dconf"
        ];
      };
    })
  ];
}
