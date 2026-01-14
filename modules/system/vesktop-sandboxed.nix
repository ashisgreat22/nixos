# Vesktop Sandboxed with nix-bwrapper
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  # Define specific Vesktop version to avoid build errors from source
  vesktop-bin = pkgs.stdenv.mkDerivation rec {
    pname = "vesktop";
    version = "1.6.3";

    src = pkgs.fetchurl {
      url = "https://github.com/Vencord/Vesktop/releases/download/v${version}/vesktop_${version}_amd64.deb";
      sha256 = "0c6k82rb21p0xi6c3xm5zrzbrph1v6x9qg0kmy9zxwv0z9lq47la";
    };

    nativeBuildInputs = [
      pkgs.dpkg
      pkgs.makeWrapper
    ];

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r usr/* $out/
      runHook postInstall
    '';

    meta.mainProgram = "vesktop";
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      vesktop-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = vesktop-bin;
          id = "dev.vencord.Vesktop";
          env = {
            # Propagate XDG_DATA_DIRS for theming
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            # Force Wayland
            NIXOS_OZONE_WL = "1";
          };
        };

        # Enable X11 and Wayland
        sockets.x11 = true;
        sockets.wayland = true;

        # Disable flatpak emulation
        flatpak.enable = false;

        fhsenv.opts = {
          unshareUser = true;
          unshareUts = false;
          unshareCgroup = false;
          unsharePid = false;
          unshareNet = false; # Need network for Discord
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
            "$HOME/.config/vesktop"
            "$HOME/Downloads"
          ];
        };

        # Disable built-in DBus module (invokes bwrap without --unshare-user)
        dbus.enable = false;

        # Manually set up DBus proxy with --unshare-user (session bus only)
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          appId = "dev.vencord.Vesktop";
          enableSystemBus = false;
          proxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.portal.*"''
            ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
            ''--talk="org.freedesktop.Notifications"''
            ''--talk="org.freedesktop.ScreenSaver"''
            ''--talk="org.kde.StatusNotifierWatcher"''
            ''--talk="org.gnome.Mutter.DisplayConfig"''
            ''--talk="com.canonical.AppMenu.Registrar"''
            ''--own="dev.vencord.Vesktop"''
            ''--own="dev.vencord.Vesktop.*"''
          ];
        };

        fhsenv.bwrap.additionalArgs = [
          # D-Bus session proxy only
          ''--bind "$XDG_RUNTIME_DIR/app/dev.vencord.Vesktop/bus" "$XDG_RUNTIME_DIR/bus"''

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
