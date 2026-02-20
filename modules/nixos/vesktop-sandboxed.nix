# Vesktop Sandboxed with nix-bwrapper
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.vesktopSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };

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
  options.myModules.vesktopSandboxed = {
    enable = lib.mkEnableOption "sandboxed Vesktop with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
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

          fhsenv.bwrap.baseArgs = lib.mkForce (sandboxUtils.mkCommonBindArgs { inherit config lib; } ++ sandboxUtils.mkGamingBindArgs { });

          mounts = {
            read = sandboxUtils.mkGuiMounts.read;
            readWrite = [
              "$HOME/.config/vesktop"
              "$HOME/Downloads"
            ] ++ cfg.extraBindMounts;
          };

          # Disable built-in DBus module (invokes bwrap without --unshare-user)
          dbus.enable = false;

          # Manually set up DBus proxy with --unshare-user (session bus only)
          script.preCmds.stage2 = sandboxUtils.mkDbusProxyScript {
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

          fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
            # D-Bus session proxy only
            ''--bind "$XDG_RUNTIME_DIR/app/dev.vencord.Vesktop/bus" "$XDG_RUNTIME_DIR/bus"''
          ];
        };
      })
    ];

    environment.systemPackages = [ pkgs.vesktop-sandboxed ];
  };
}
