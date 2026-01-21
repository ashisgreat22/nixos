{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  pname = "tutanota-desktop";
  version = "319.260107.1";

  src = pkgs.fetchurl {
    url = "https://github.com/tutao/tutanota/releases/download/tutanota-desktop-release-${version}/tutanota-desktop-linux.AppImage";
    sha256 = "0gjvh3f70mmr85kx3kz4yd8gfxpk4kj8wkh697a4gy34mgxpqnka";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };

  tutanota = pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/tutanota-desktop.desktop $out/share/applications/tutanota-desktop.desktop
      install -m 444 -D ${appimageContents}/tutanota-desktop.png \
        $out/share/icons/hicolor/512x512/apps/tutanota-desktop.png
      substituteInPlace $out/share/applications/tutanota-desktop.desktop \
        --replace 'Exec=AppRun' 'Exec=tutanota-desktop'
    '';
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      tutanota-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = tutanota;
          id = "com.tutanota.Tutanota";
          env = {
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
          };
        };

        flatpak.enable = false;

        # Basic sandboxing
        fhsenv.opts = {
          unshareUser = true;
          unshareUts = true;
          unshareCgroup = true;
          unsharePid = true;
          unshareNet = false; # Needs network
          unshareIpc = true;
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
            "$HOME/.config/tutanota-desktop"
            "$HOME/Downloads"
          ];
        };

        dbus.enable = false;
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          appId = "com.tutanota.Tutanota";
          enableSystemBus = false;
          proxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.portal.*"''
            ''--talk="org.freedesktop.Notifications"''
            ''--talk="org.freedesktop.secrets"''
            ''--talk="org.gnome.keyring.SystemPrompter"'' # Often needed for secrets
            ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
            ''--own="com.tutanota.Tutanota"''
          ];
        };

        fhsenv.bwrap.additionalArgs = [
          # D-Bus session proxy only
          ''--bind "$XDG_RUNTIME_DIR/app/com.tutanota.Tutanota/bus" "$XDG_RUNTIME_DIR/bus"''
          # Wayland
          ''--bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"''
        ];
      };
    })
  ];
}
