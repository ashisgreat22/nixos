{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.braveSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };

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
  options.myModules.braveSandboxed = {
    enable = lib.mkEnableOption "sandboxed Brave with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };

    useProxy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to use the wireproxy SOCKS5 proxy";
    };

    proxyAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "The address of the SOCKS5 proxy";
    };

    proxyPort = lib.mkOption {
      type = lib.types.int;
      default = 1080;
      description = "The port of the SOCKS5 proxy";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        brave-sandboxed = bwrapperPkgs.mkBwrapper {
          app = {
            package =
              let
                braveExe = lib.getExe prev.brave;
                binName = builtins.baseNameOf braveExe;
              in
              pkgs.symlinkJoin {
                name = "brave-wrapped";
                inherit (prev.brave) pname version meta;
                paths = [ prev.brave ];
                nativeBuildInputs = [ pkgs.makeWrapper ];
                postBuild = ''
                  ${lib.optionalString cfg.useProxy ''
                    rm -f $out/bin/${binName}
                    makeWrapper ${braveExe} $out/bin/${binName} \
                      --add-flags "--proxy-server=socks5://127.0.0.1:${toString cfg.proxyPort}" \
                      --run '
                        (
                          SOCKET="/run/user/${toString config.users.users.${config.myModules.system.mainUser}.uid}/brave-proxy.sock"
                          for i in $(seq 1 50); do
                            if [ -S "$SOCKET" ]; then
                              ${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.proxyPort},fork UNIX-CLIENT:"$SOCKET"
                              exit 0
                            fi
                            sleep 0.1
                          done
                          echo "Error: Brave proxy socket not found at $SOCKET" >&2
                          exit 1
                        ) &
                      '
                  ''}
                  rm -f $out/share/applications/com.brave.Browser.desktop
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
            unsharePid = true;
            unshareNet = cfg.useProxy;
            unshareIpc = true;
          };

          fhsenv.bwrap.baseArgs = lib.mkForce (
            sandboxUtils.mkCommonBindArgs { inherit config lib; }
            ++ sandboxUtils.mkGamingBindArgs { }
            ++ [
              "--tmpfs /mnt"
              "--ro-bind-try /run/booted-system /run/booted-system"
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
              # Expose GPU device nodes
              "--dev-bind /dev/dri /dev/dri"
            ]
          );

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
            ] ++ cfg.extraBindMounts;
          };

          # Bind mount systemd-resolved socket for DNS and required system files
          # Disable built-in DBus module because it invokes bwrap without --unshare-user
          dbus.enable = false;

          # Manually set up DBus proxy with --unshare-user
          script.preCmds.stage2 = sandboxUtils.mkDbusProxyScript {
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

          fhsenv.bwrap.additionalArgs =
            sandboxUtils.mkGuiBindArgs { }
            ++ [
              ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.brave/bus" "$XDG_RUNTIME_DIR/bus"''
              ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.brave/bus_system" /run/dbus/system_bus_socket''
              "--bind-try /run/user/${
                toString config.users.users.${config.myModules.system.mainUser}.uid
              }/dconf /run/user/${toString config.users.users.${config.myModules.system.mainUser}.uid}/dconf"
            ]
            ++ lib.optionals cfg.useProxy [
              "--bind-try /run/user/${
                toString config.users.users.${config.myModules.system.mainUser}.uid
              }/brave-proxy.sock /run/user/${
                toString config.users.users.${config.myModules.system.mainUser}.uid
              }/brave-proxy.sock"
            ];
        };
      })
    ];

    environment.systemPackages = [ pkgs.brave-sandboxed ];

    systemd.user.services.brave-proxy-bridge = lib.mkIf cfg.useProxy {
      description = "Bridge SOCKS5 proxy to UNIX socket for Brave Sandbox";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:%t/brave-proxy.sock,fork TCP:${cfg.proxyAddress}:${toString cfg.proxyPort}";
        Restart = "always";
      };
    };
  };
}