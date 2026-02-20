# PrismLauncher Sandboxed with nix-bwrapper
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.prismlauncherSandboxed;
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
  sandboxUtils = import ./sandbox-utils.nix { inherit pkgs lib; };

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
  options.myModules.prismlauncherSandboxed = {
    enable = lib.mkEnableOption "sandboxed PrismLauncher with nix-bwrapper";

    extraBindMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to bind mount (read-write) into the sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        prismlauncher-sandboxed = bwrapperPkgs.mkBwrapper {
          app = {
            id = "org.prismlauncher.PrismLauncher";
            package = pkgs.prismlauncher.overrideAttrs (old: {
              pname = "prismlauncher";
              version = old.version or "9.1";
              buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.mimalloc ];

              # Keep runtimeLibs in closure without injecting them into environment
              postInstall = (old.postInstall or "") + ''
                mkdir -p $out/share/prismlauncher-sandboxed
                echo "${lib.makeLibraryPath runtimeLibs}" > $out/share/prismlauncher-sandboxed/libs
              '';

              qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
                "--set MIMALLOC_PATH ${pkgs.mimalloc}/lib/libmimalloc.so"
                "--prefix LD_PRELOAD : ${pkgs.mimalloc}/lib/libmimalloc.so"
              ];
            });

            env = {
              # Propagate XDG_DATA_DIRS so themes/icons can be found
              # XDG_DATA_DIRS = "$XDG_DATA_DIRS";
              BROWSER = "firefox";
              QT_QPA_PLATFORMTHEME = "";
              QT_STYLE_OVERRIDE = "fusion";
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

          fhsenv.bwrap.baseArgs = lib.mkForce (sandboxUtils.mkCommonBindArgs { inherit config lib; } ++ sandboxUtils.mkGamingBindArgs { } ++ [
            "--ro-bind /run/dbus /run/dbus"
          ]);

          mounts = {
            read = sandboxUtils.mkGuiMounts.read ++ [
              "$HOME/Downloads"
            ];
            readWrite = [
              "$HOME/.local/share/PrismLauncher"
              "$HOME/.cache/PrismLauncher"
            ] ++ cfg.extraBindMounts;
          };

          dbus.enable = false;

          script.preCmds.stage2 =
            let
              jvmArgs = "-XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseVectorCmov -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:ThreadPriorityPolicy=1 -XX:AllocatePrefetchStyle=3 -XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:ShenandoahGuaranteedGCInterval=1000000 -XX:AllocatePrefetchStyle=1 -XX:ConcGCThreads=4";
              glfwPath = "${pkgs.glfw}/lib/libglfw.so.3";

              dbusScript = sandboxUtils.mkDbusProxyScript {
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

          fhsenv.bwrap.additionalArgs = sandboxUtils.mkGuiBindArgs { } ++ [
            # D-Bus proxy
            ''--bind "$XDG_RUNTIME_DIR/app/org.prismlauncher.PrismLauncher/bus" "$XDG_RUNTIME_DIR/bus"''
          ];
        };
      })
    ];

    environment.systemPackages = [ pkgs.prismlauncher-sandboxed ];
  };
}
