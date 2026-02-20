{
  config,
  lib,
  pkgs,
  inputs,
  ...}:

let
  cfg = config.myModules.tutanotaSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };

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
  options.myModules.tutanotaSandboxed = {
    enable = lib.mkEnableOption "sandboxed Tutanota Desktop with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
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

          fhsenv.bwrap.baseArgs = lib.mkForce (sandboxUtils.mkCommonBindArgs { inherit config lib; } ++ sandboxUtils.mkGamingBindArgs { });

          mounts = {
            read = sandboxUtils.mkGuiMounts.read;
            readWrite = [
              "$HOME/.config/tutanota-desktop"
              "$HOME/Downloads"
            ] ++ cfg.extraBindMounts;
          };

          dbus.enable = false;
          script.preCmds.stage2 = sandboxUtils.mkDbusProxyScript {
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

          fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
            # D-Bus session proxy only
            ''--bind "$XDG_RUNTIME_DIR/app/com.tutanota.Tutanota/bus" "$XDG_RUNTIME_DIR/bus"''
          ];
        };
      })
    ];

    environment.systemPackages = [ pkgs.tutanota-sandboxed ];
  };
}
