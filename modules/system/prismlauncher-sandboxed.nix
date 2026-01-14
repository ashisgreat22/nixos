# PrismLauncher Sandboxed with nix-bwrapper
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

  # Libraries required by Minecraft natives (LWJGL), various mods,
  # and the Microsoft authentication flow (NSS/NSPR).
  runtimeLibs = with pkgs; [
    glib
    libgbm
    libglvnd
    nspr
    nss
    gtk3
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
    pango
    cairo
    at-spi2-atk
    at-spi2-core
    libxml2
    libxml2
    xorg.libXScrnSaver
    glfw
    # Kvantum Style Plugins
    # Kvantum Style Plugins
    kdePackages.qtstyleplugin-kvantum
  ];
in
{
  nixpkgs.overlays = [
    (final: prev: {
      prismlauncher-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          id = "org.prismlauncher.PrismLauncher";
          package =
            inputs.prismlauncher.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher.overrideAttrs
              (old: {
                pname = "prismlauncher";
                version = old.version or "9.1";
                buildInputs = (old.buildInputs or [ ]) ++ runtimeLibs ++ [ pkgs.mimalloc ];

                qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
                  "--set MIMALLOC_PATH ${pkgs.mimalloc}/lib/libmimalloc.so"
                  "--prefix LD_PRELOAD : ${pkgs.mimalloc}/lib/libmimalloc.so"
                  "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}"
                  "--prefix QT_PLUGIN_PATH : ${pkgs.kdePackages.qtstyleplugin-kvantum}/lib/qt6/plugins"
                ];
              });

          env = {
            # Propagate XDG_DATA_DIRS so themes/icons can be found
            XDG_DATA_DIRS = "$XDG_DATA_DIRS";
            GTK_THEME = "catppuccin-mocha-mauve-standard";
            QT_QPA_PLATFORMTHEME = "gtk3";
            QT_STYLE_OVERRIDE = "kvantum";
            BROWSER = "firefox";
          };
        };

        sockets.x11 = true; # Old versions of minecraft require X11, and forge still doesnt care its breaking wayland.
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
          "--dir /run/user/${toString config.users.users.ashie.uid}"
          # Bind ro system paths commonly needed
          "--ro-bind-try /run/current-system /run/current-system"
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
            jvmArgs = "-XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseVectorCmov -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:ThreadPriorityPolicy=1 -XX:AllocatePrefetchStyle=3 -XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:ShenandoahGuaranteedGCInterval=1000000 -XX:AllocatePrefetchStyle=1 -XX:ConcGCThreads=4";
            glfwPath = "${pkgs.glfw}/lib/libglfw.so.3";

            dbusScript = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
              appId = "org.prismlauncher.PrismLauncher";
              proxyArgs = [
                "--filter"
                ''--talk="org.freedesktop.portal.*"''
                ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
                ''--talk="org.freedesktop.Notifications"''
                ''--own="org.prismlauncher.PrismLauncher"''
                ''--own="org.prismlauncher.PrismLauncher.*"''
              ];
            };
          in
          ''
            ${dbusScript}

            # Force Configs (JVM Args + GLFW)
            cfg="$HOME/.local/share/PrismLauncher/prismlauncher.cfg"
            if [ -f "$cfg" ]; then
              # JVM Args
              if ${pkgs.gnugrep}/bin/grep -q "^JvmArgs=" "$cfg"; then
                ${pkgs.gnused}/bin/sed -i "s|^JvmArgs=.*|JvmArgs=${jvmArgs}|" "$cfg"
              else
                 if ${pkgs.gnugrep}/bin/grep -q "^\[General\]" "$cfg"; then
                    ${pkgs.gnused}/bin/sed -i "/^\[General\]/a JvmArgs=${jvmArgs}" "$cfg"
                 else
                    echo "JvmArgs=${jvmArgs}" >> "$cfg"
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
          ''--bind "$XDG_RUNTIME_DIR/app/org.prismlauncher.PrismLauncher/bus" "$XDG_RUNTIME_DIR/bus"''

          # Wayland socket
          ''--bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"''

          # PipeWire + Pulse (PipeWire hosts both)
          ''--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"''
          ''--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"''
        ];
      };
    })
  ];
}
