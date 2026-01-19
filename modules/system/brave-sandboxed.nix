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

  # Define policies.json with Catppuccin Mocha Theme (Chrome Web Store)
  bravePolicies = pkgs.writeText "policies.json" (
    builtins.toJSON {
      ExtensionInstallForcelist = [
        "pgonbchglnnkjolggcdhphlbnjihfofh;https://clients2.google.com/service/update2/crx" # Catppuccin Mocha
      ];
    }
  );
in
{
  nixpkgs.overlays = [
    (final: prev: {
      brave-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = pkgs.symlinkJoin {
            name = "brave-single-desktop";
            paths = [ prev.brave ];
            inherit (prev.brave) pname version meta;
            postBuild = ''
              rm $out/share/applications/com.brave.Browser.desktop
            '';
          };
          # id = "brave-browser"; # Omit app.id to avoid potential bind errors (like Firefox)
          env = {
            # Propagate XDG_DATA_DIRS so GTK can find themes in user profile/system
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            GTK_THEME = "catppuccin-mocha-mauve-standard";
            HYPRCURSOR_THEME = "Future-Cyan-Hyprcursor_Theme";
            HYPRCURSOR_SIZE = "32";
            # Force ozone/wayland usage for Brave/Chromium
            NIXOS_OZONE_WL = "1";
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
          # Brave flags
          "--setenv NIXOS_OZONE_WL \"1\""
          "--setenv NOTIFY_IGNORE_PORTAL 1"
          # Bind policies for Theme
          "--dir /etc/brave/policies/managed"
          "--ro-bind ${bravePolicies} /etc/brave/policies/managed/policies.json"
          # Fallback paths for Chromium/Chrome base
          "--dir /etc/chromium/policies/managed"
          "--ro-bind ${bravePolicies} /etc/chromium/policies/managed/policies.json"
          "--dir /etc/opt/chrome/policies/managed"
          "--ro-bind ${bravePolicies} /etc/opt/chrome/policies/managed/policies.json"
        ];

        # Filesystem: Limited to Brave directories and Downloads
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
            "$HOME/.config/BraveSoftware"
            "$HOME/.cache/BraveSoftware"
            "$HOME/Downloads"
          ];
        };

        # Bind mount systemd-resolved socket for DNS and required system files
        # Disable built-in DBus module because it invokes bwrap without --unshare-user
        dbus.enable = false;

        # Manually set up DBus proxy with --unshare-user
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          appId = "nix.bwrapper.brave";
          proxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.portal.Desktop"''
            ''--talk="org.freedesktop.portal.OpenURI"''
            ''--talk="org.freedesktop.portal.FileChooser"''
            ''--talk="org.freedesktop.secrets"''
            ''--talk="org.kde.StatusNotifierWatcher"''
            ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
            ''--own="org.chromium.LibCrosService"'' # Chromium/Brave specific
            ''--own="org.mpris.MediaPlayer2.chromium.*"''
            ''--own="org.mpris.MediaPlayer2.brave.*"''
          ];
          enableSystemBus = true;
          systemProxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.NetworkManager"''
          ];
        };

        fhsenv.bwrap.additionalArgs = [
          ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.brave/bus" "$XDG_RUNTIME_DIR/bus"''
          ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.brave/bus_system" /run/dbus/system_bus_socket''
          "--dir /run/systemd/resolve"
          "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
          "--bind-try /run/user/${toString config.users.users.ashie.uid}/dconf /run/user/${toString config.users.users.ashie.uid}/dconf"
        ];
      };
    })
  ];

  environment.systemPackages =
    let
      vpnLauncher = pkgs.writeShellScriptBin "brave-vpn" ''
        exec /home/ashie/nixos/scripts/launch-vpn-app.sh ${pkgs.brave-sandboxed}/bin/brave "$@"
      '';

      desktopItem = pkgs.makeDesktopItem {
        name = "brave-vpn";
        desktopName = "Brave (VPN)";
        exec = "${vpnLauncher}/bin/brave-vpn";
        icon = "brave-browser";
        categories = [
          "Network"
          "WebBrowser"
        ];
      };
    in
    [
      vpnLauncher
      desktopItem
    ];
}
