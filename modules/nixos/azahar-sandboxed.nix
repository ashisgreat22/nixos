{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  pname = "azahar";
  version = "2123.4";

  src = pkgs.fetchurl {
    url = "https://github.com/azahar-emu/azahar/releases/download/2123.4/azahar.AppImage";
    sha256 = "0x9k5kamn7lr5frffzv5vdgxv65cwwb01pbf6dyb8p2dw63cq87a";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };

  azahar = pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/usr/share/applications/azahar.desktop $out/share/applications/azahar.desktop
      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/scalable/apps/org.azahar_emu.Azahar.svg \
        $out/share/icons/hicolor/scalable/apps/azahar.svg

      substituteInPlace $out/share/applications/azahar.desktop \
        --replace 'Exec=AppRun' 'Exec=azahar'
    '';
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      azahar-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = azahar;
          id = "org.azahar_emu.Azahar";
          env = {
            QT_QPA_PLATFORM = "wayland;xcb";
            XDG_CURRENT_DESKTOP = "KDE";
          };
        };

        flatpak.enable = false;
        fhsenv.bwrap.additionalArgs = [
          "--dir /run/systemd/resolve"
          "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
          ''--bind "$XDG_RUNTIME_DIR/app/org.azahar_emu.Azahar/bus" "$XDG_RUNTIME_DIR/bus"''
        ];

        mounts = {
          read = [
            "$HOME/.config/kdedefaults"
            "$HOME/.local/share/color-schemes"
            "$HOME/.config/fontconfig"
            "$HOME/.icons"
            "$HOME/.config/MangoHud"
          ];
          readWrite = [
            "$HOME/Games/3DS"
            "$HOME/.config/azahar"
            "$HOME/.local/share/azahar"
          ];
        };

        dbus.enable = false;
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          appId = "org.azahar_emu.Azahar";
          enableSystemBus = false;
          proxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.Flatpak"''
            ''--talk="org.kde.StatusNotifierWatcher"''
            ''--talk="org.kde.KWin"''
            ''--talk="org.gnome.Mutter.DisplayConfig"''
            ''--talk="org.freedesktop.ScreenSaver"''
            ''--talk="org.freedesktop.portal.Desktop"''
            ''--talk="org.freedesktop.portal.OpenURI"''
            ''--talk="org.freedesktop.secrets"''
            ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
          ];
        };
      };
    })
  ];
}
