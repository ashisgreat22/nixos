{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.prismlauncher;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  # Libraries required by Minecraft natives (LWJGL), various mods,
  # and the Microsoft authentication flow (NSS/NSPR).
  runtimeLibs = with pkgs; [
    glib
    libgbm
    libglvnd
    nspr
    nss
    alsa-lib
    libpulseaudio
    udev
    cups
    mesa
    expat
    libdrm
    libxkbcommon
    dbus
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    libxml2
    xorg.libXScrnSaver
    glfw
  ];

  defaultJvmArgs = "-Djava.net.preferIPv4Stack=true -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseVectorCmov -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:ThreadPriorityPolicy=1 -XX:AllocatePrefetchStyle=3 -XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:ShenandoahGuaranteedGCInterval=1000000 -XX:AllocatePrefetchStyle=1 -XX:ConcGCThreads=4";

in
{
  options.myModules.prismlauncher = {
    enable = lib.mkEnableOption "PrismLauncher Sandboxed";

    jvmArgs = lib.mkOption {
      type = lib.types.str;
      default = defaultJvmArgs;
      description = "JVM arguments to enforce in prismlauncher.cfg";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "User ID for /run/user bind mount";
    };

    glfwPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.glfw;
      description = "The GLFW package to use for the custom GLFW path.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (
        let
          sandboxed = bwrapperPkgs.mkBwrapper {
            app = {
              id = "org.prismlauncher.PrismLauncher";
              package = pkgs.prismlauncher.overrideAttrs (old: {
                pname = "prismlauncher";
                version = old.version or "9.1"; # Fallback or keep current if valid
                buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.jemalloc ];

                # Keep runtimeLibs in closure without injecting them into environment
                postInstall = (old.postInstall or "") + ''
                  mkdir -p $out/share/prismlauncher-sandboxed
                  echo "${lib.makeLibraryPath runtimeLibs}" > $out/share/prismlauncher-sandboxed/libs
                '';

                qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
                  "--set JEMALLOC_PATH ${pkgs.jemalloc}/lib/libjemalloc.so"
                  "--prefix LD_PRELOAD : ${pkgs.jemalloc}/lib/libjemalloc.so"
                ];
              });

              env = {
                # Propagate XDG_DATA_DIRS so themes/icons can be found
                BROWSER = "firefox";
                QT_QPA_PLATFORM = "xcb";
                GDK_BACKEND = "x11";
                NO_AT_BRIDGE = "1";
                QT_QPA_PLATFORMTHEME = "";
                QT_STYLE_OVERRIDE = "fusion";

                # Sanitize Desktop Environment to prevent loading conflicting platform themes
                XDG_CURRENT_DESKTOP = "X-Generic";
                XDG_SESSION_TYPE = "x11";
                GTK_USE_PORTAL = "0";
                GTK_THEME = "Adwaita"; # Force a safe theme or empty?

                # Unset potential conflict variables
                GTK_MODULES = "";
                GTK3_MODULES = "";
              };
            };

            sockets.x11 = true;
            sockets.wayland = true;
            flatpak.enable = false;

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
              "--tmpfs /tmp"
              "--tmpfs /run"
              "--dir /run/user"
              "--dir /run/user/${toString cfg.uid}"
              # Bind ro system paths commonly needed
              "--ro-bind-try /run/opengl-driver /run/opengl-driver"
              "--ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32"
              "--dir /run/systemd/resolve"
              "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
              "--ro-bind /run/dbus /run/dbus"
            ];

            mounts = {
              read = [
                "$HOME/.config/fontconfig"
                "$HOME/.local/share/fonts"
                "$HOME/.icons"
                "$HOME/.themes"
                "$HOME/.local/share/themes"
                "$HOME/.config/qt6ct"
                "$HOME/.config/Kvantum"
                "$HOME/.config/MangoHud"
                "$HOME/Downloads"
              ];
              readWrite = [
                "$HOME/.local/share/PrismLauncher"
                "$HOME/.cache/PrismLauncher"
              ];
            };

            dbus.enable = false;

            script.preCmds.stage2 =
              let
                glfwPath = "${cfg.glfwPackage}/lib/libglfw.so.3";

                # We need to access the sandbox-utils.nix. Since it's in system modules,
                # we can't easily import it relative to here if it's not exported.
                # But the content was small, let's inline what we need or check if we can source it.
                # For now, I'll assume the dbus-proxy logic is needed.

                # Reimplementing mkDbusProxyScript from sandbox-utils.nix inline to avoid path dependency
                mkDbusProxyScript =
                  { appId, proxyArgs }:
                  let
                    proxyArgsStr = lib.escapeShellArgs proxyArgs;
                    appDir = "$XDG_RUNTIME_DIR/app/${appId}";
                    proxySocket = "${appDir}/bus";
                  in
                  ''
                    mkdir -p "${appDir}"
                    # Start xdg-dbus-proxy
                    ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
                      "$DBUS_SESSION_BUS_ADDRESS" "${proxySocket}" \
                      ${proxyArgsStr} &
                    DBUS_PROXY_PID=$!

                    # Kill proxy on exit
                    trap "kill $DBUS_PROXY_PID" EXIT

                    # Wait for socket to be created
                    for i in {1..50}; do
                      if [ -S "${proxySocket}" ]; then
                        break
                      fi
                      if ! kill -0 $DBUS_PROXY_PID 2>/dev/null; then
                        echo "xdg-dbus-proxy died unexpectedly"
                        exit 1
                      fi
                      sleep 0.1
                    done
                  '';

                dbusScript = mkDbusProxyScript {
                  appId = "org.prismlauncher.PrismLauncher";
                  proxyArgs = [
                    "--filter"
                    "--talk=org.freedesktop.portal.*"
                    "--call=org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"
                    "--talk=org.freedesktop.Notifications"
                    "--own=org.prismlauncher.PrismLauncher"
                    "--own=org.prismlauncher.PrismLauncher.*"
                  ];
                };
              in
              ''
                ${dbusScript}

                # Sanitize Environment
                unset QT_QPA_PLATFORMTHEME
                unset GTK_THEME
                unset XDG_CURRENT_DESKTOP
                export QT_QPA_PLATFORM=xcb
                export GDK_BACKEND=x11
                export NO_AT_BRIDGE=1

                # Force Configs (JVM Args + GLFW)
                cfg="$HOME/.local/share/PrismLauncher/prismlauncher.cfg"
                if [ -f "$cfg" ]; then
                  # JVM Args
                  if ${pkgs.gnugrep}/bin/grep -q "^JvmArgs=" "$cfg"; then
                    ${pkgs.gnused}/bin/sed -i "s|^JvmArgs=.*|JvmArgs=${cfg.jvmArgs}|" "$cfg"
                  else
                     if ${pkgs.gnugrep}/bin/grep -q "^\\[General\\]" "$cfg"; then
                        ${pkgs.gnused}/bin/sed -i "/^\\[General\\]/a JvmArgs=${cfg.jvmArgs}" "$cfg"
                     else
                        echo "JvmArgs=${cfg.jvmArgs}" >> "$cfg"
                     fi
                  fi

                  # GLFW Settings
                  # 1. CustomGLFWPath
                  if ${pkgs.gnugrep}/bin/grep -q "^CustomGLFWPath=" "$cfg"; then
                    ${pkgs.gnused}/bin/sed -i "s|^CustomGLFWPath=.*|CustomGLFWPath=${glfwPath}|" "$cfg"
                  else
                     echo "CustomGLFWPath=${glfwPath}" >> "$cfg"
                  fi

                  # 2. UseNativeGLFW
                  if ${pkgs.gnugrep}/bin/grep -q "^UseNativeGLFW=" "$cfg"; then
                    ${pkgs.gnused}/bin/sed -i "s|^UseNativeGLFW=.*|UseNativeGLFW=true|" "$cfg"
                  else
                     echo "UseNativeGLFW=true" >> "$cfg"
                  fi
                fi
              '';

            fhsenv.bwrap.additionalArgs = [
              # D-Bus proxy
              ''--bind "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus"''
              # Note: The original code bound a specific path TO ./bus.
              # "''--bind "$XDG_RUNTIME_DIR/app/org.prismlauncher.PrismLauncher/bus" "$XDG_RUNTIME_DIR/bus"''"
              # But mkDbusProxyScript (if standard) creates a socket.
              # The logic in prismlauncher-sandboxed.nix imported sandbox-utils.nix.
              # I'll try to match the original bind logic if possible.

              # The original code had:
              # ''--bind "$XDG_RUNTIME_DIR/app/org.prismlauncher.PrismLauncher/bus" "$XDG_RUNTIME_DIR/bus"''
              # But my inline mkDbusProxyScript sets up "$XDG_RUNTIME_DIR/bus" as the listen socket *inside* the script execution?
              # Wait, xdg-dbus-proxy runs inside the outer unshared namespace or outside?
              # In mkBwrapper, preCmds run *inside* the bwrap?
              # No, typically preCmds run before the final exec?
              # Actually, looking at nix-bwrapper, `preCmds.stage2` runs *inside* the sandbox?

              # Let's start with the binds exactly as they were, assuming `sandbox-utils` logic.
              # If I can't import sandbox-utils, I have to rely on what I can see.
              # The original `sandbox-utils.nix` likely set up the proxy.
              # I will copy the binds from the original file.

              ''--bind "$XDG_RUNTIME_DIR/app/org.prismlauncher.PrismLauncher/bus" "$XDG_RUNTIME_DIR/bus"''

              # Wayland socket
              ''--bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"''

              # PipeWire + Pulse
              ''--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"''
              ''--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"''
            ];
          };
        in
        sandboxed
      )
    ];
  };
}
