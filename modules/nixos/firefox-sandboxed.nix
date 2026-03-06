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
          "network.manage-offline-status" = false;
          "network.captive-portal-service.enabled" = false;
          "widget.use-xdg-desktop-portal.file-picker" = 1;
        }
        // (
          if cfg.useProxy then
            {
              # Always 127.0.0.1: the internal socat listener binds locally
              # inside the sandbox regardless of where cfg.proxyAddress lives
              # on the host. Pointing Firefox at cfg.proxyAddress would fail
              # when it isn't 127.0.0.1 because that address doesn't exist
              # inside the isolated network namespace.
              "network.proxy.socks" = "127.0.0.1";
              "network.proxy.socks_port" = cfg.proxyPort;
              "network.proxy.type" = 1;
              "network.proxy.socks_remote_dns" = true;
            }
          else
            { }
        );
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
        firefox-sandboxed = bwrapperPkgs.mkBwrapper {
          app = {
            package =
              if cfg.useProxy then
                pkgs.symlinkJoin {
                  name = "firefox-esr-proxy-wrapped";
                  inherit (prev.firefox-esr) pname version meta;
                  paths = [ prev.firefox-esr ];
                  nativeBuildInputs = [ pkgs.makeWrapper ];
                  postBuild =
                    let
                      firefoxExe = lib.getExe prev.firefox-esr;
                      binName = builtins.baseNameOf firefoxExe;
                    in
                    ''
                      rm -f $out/bin/${binName}
                      makeWrapper ${firefoxExe} $out/bin/${binName} \
                        --run '${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.proxyPort},fork UNIX-CLIENT:/run/user/${
                          toString config.users.users.${config.myModules.system.mainUser}.uid
                        }/firefox-proxy.sock &'
                    '';
                }
              else
                prev.firefox-esr;
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
              "--setenv MOZ_ENABLE_WAYLAND \"1\""
              "--setenv NOTIFY_IGNORE_PORTAL 1"
              "--dir /etc"
              "--dir /etc/firefox"
              "--dir /etc/firefox/policies"
              "--ro-bind ${firefoxPolicies} /etc/firefox/policies/policies.json"
              # Expose GPU device nodes so Firefox can use hardware acceleration
              # (VA-API / VDPAU / WebGL). Without this it falls back to software
              # rendering on pure-Wayland sessions.
              "--dev-bind /dev/dri /dev/dri"
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

          fhsenv.bwrap.additionalArgs =
            sandboxUtils.mkGuiBindArgs { }
            ++ [
              ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.firefox/bus" "$XDG_RUNTIME_DIR/bus"''
              ''--bind "$XDG_RUNTIME_DIR/app/nix.bwrapper.firefox/bus_system" /run/dbus/system_bus_socket''
              "--bind-try /run/user/${
                toString config.users.users.${config.myModules.system.mainUser}.uid
              }/dconf /run/user/${toString config.users.users.${config.myModules.system.mainUser}.uid}/dconf"
            ]
            ++ lib.optionals cfg.useProxy [
              "--bind-try /run/user/${
                toString config.users.users.${config.myModules.system.mainUser}.uid
              }/firefox-proxy.sock /run/user/${
                toString config.users.users.${config.myModules.system.mainUser}.uid
              }/firefox-proxy.sock"
            ];
        };
      })
    ];

    environment.systemPackages = [ pkgs.firefox-sandboxed ];

    systemd.user.services.firefox-proxy-bridge = lib.mkIf cfg.useProxy {
      description = "Bridge SOCKS5 proxy to UNIX socket for Firefox Sandbox";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:%t/firefox-proxy.sock,fork TCP:${cfg.proxyAddress}:${toString cfg.proxyPort}";
        Restart = "always";
      };
    };
  };
}
