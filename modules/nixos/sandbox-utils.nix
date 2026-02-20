{ pkgs, lib }:

let
  # Generates the shell script content to set up xdg-dbus-proxy inside a bwrap user namespace.
  # This is used for sandboxed apps that run with unshareUser = true.
  mkDbusProxyScript =
    {
      appId,
      # Unique ID for the app (e.g. "org.mozilla.firefox")
      proxyArgs, # Arguments for xdg-dbus-proxy (session bus). Can be string or list.
      socketPath ? "$XDG_RUNTIME_DIR/app/${appId}/bus",
      upstreamSocket ? "$XDG_RUNTIME_DIR/bus",
      enableSystemBus ? false,
      systemProxyArgs ? "", # Arguments for xdg-dbus-proxy (system bus). Can be string or list.
      systemSocketPath ? "$XDG_RUNTIME_DIR/app/${appId}/bus_system",
      systemUpstreamSocket ? "/run/dbus/system_bus_socket",
    }:
    let
      bwrap = "${pkgs.bubblewrap}/bin/bwrap";
      dbusProxy = "${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy";
      coreutils = "${pkgs.coreutils}/bin";

      # Helper to normalize args (support list or string)
      normalizeArgs = args: if builtins.isList args then lib.concatStringsSep " " args else args;
      pArgs = normalizeArgs proxyArgs;
      sArgs = normalizeArgs systemProxyArgs;

      # Helper to generate the function definition
      # We bind XDG_RUNTIME_DIR to allow creating the socket.
      # We optionally bind /run/dbus for the system bus socket.
      mkProxyFunc = name: upstream: sock: args: bindSystem: ''
        ${name}() {
          ${coreutils}/mkdir -p "$(${coreutils}/dirname "${sock}")"
          ${bwrap} \
            --unshare-user \
            --dev /dev \
            --proc /proc \
            --new-session \
            --ro-bind /nix/store /nix/store \
            --bind "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR" \
            ${if bindSystem then "--ro-bind /run/dbus /run/dbus" else ""} \
            --die-with-parent \
            --clearenv \
            -- \
            ${dbusProxy} "unix:path=${upstream}" "${sock}" ${args}
        }
      '';

      sessionFunc = mkProxyFunc "set_up_dbus_proxy" upstreamSocket socketPath pArgs false;
      systemFunc =
        if enableSystemBus then
          mkProxyFunc "set_up_system_dbus_proxy" systemUpstreamSocket systemSocketPath sArgs true
        else
          "";

      waitLoop = ''
        # Wait for socket(s) with fail-fast check
        for i in $(${coreutils}/seq 1 50);
        do
          # Check if processes are still running
          if ! kill -0 "$PID_SESSION" 2>/dev/null;
          then
            echo "Error: Session D-Bus proxy (PID $PID_SESSION) died unexpectedly." >&2
            exit 1
          fi
          ${
            if enableSystemBus then
              ''
                if ! kill -0 "$PID_SYSTEM" 2>/dev/null;
                then
                  echo "Error: System D-Bus proxy (PID $PID_SYSTEM) died unexpectedly." >&2
                  exit 1
                fi
              ''
            else
              ""
          }

          # Check for sockets
          if [ -S "${socketPath}" ]${if enableSystemBus then " && [ -S \"${systemSocketPath}\" ]" else ""};
          then
            break
          fi
          ${coreutils}/sleep 0.02
        done
      '';

    in
    ''
      ${sessionFunc}
      ${systemFunc}

      set_up_dbus_proxy &
      PID_SESSION=$!
      ${
        if enableSystemBus then
          ''
            set_up_system_dbus_proxy &
            PID_SYSTEM=$!
          ''
        else
          ""
      }

      ${waitLoop}
    '';

  # Standard Common Binds (System Essentials)
  mkCommonBindArgs =
    { config, lib }:
    [
      "--new-session"
      "--proc /proc"
      "--dev /dev"
      "--dev-bind-try /dev/ntsync /dev/ntsync"
      "--tmpfs /home"
      "--tmpfs /tmp"
      "--tmpfs /run"
      "--dir /run/user"
      "--dir /run/user/${toString config.users.users.${config.myModules.system.mainUser}.uid}"
      "--ro-bind /sys /sys"
      "--ro-bind-try /run/current-system /run/current-system"
      "--dir /run/systemd/resolve"
      "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
      "--unsetenv LD_PRELOAD"
    ];

  # GUI Application Binds (Fonts, Themes, Wayland/X11 sockets)
  mkGuiBindArgs =
    { }:
    [
      # Wayland socket
      ''--bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"''
      # PipeWire + Pulse
      ''--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"''
      ''--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"''
    ];

  # GUI Mounts (Fonts, Configs)
  mkGuiMounts = {
    read = [
      "$HOME/.config/fontconfig"
      "$HOME/.local/share/fonts"
      "$HOME/.icons"
      "$HOME/.themes"
      "$HOME/.local/share/themes"
      "$HOME/.config/qt6ct"
      "$HOME/.config/Kvantum"
      "$HOME/.config/MangoHud"
      "$HOME/.config/kdedefaults"
      "$HOME/.local/share/color-schemes"
      "$HOME/.config/gtk-3.0"
      "$HOME/.config/gtk-4.0"
    ];
  };

  # Gaming Binds (GPU, Controllers, Input)
  mkGamingBindArgs =
    { }:
    [
      "--dev-bind /dev/dri /dev/dri" # GPU
      "--dev-bind /dev/shm /dev/shm" # Shared Mem
      "--dev-bind-try /dev/uinput /dev/uinput"
      "--dev-bind-try /dev/input /dev/input"
      "--dev-bind-try /dev/hidraw0 /dev/hidraw0"
      "--dev-bind-try /dev/hidraw1 /dev/hidraw1"
      "--dev-bind-try /dev/hidraw2 /dev/hidraw2"
      "--dev-bind-try /dev/hidraw3 /dev/hidraw3"
      "--ro-bind-try /run/opengl-driver /run/opengl-driver"
      "--ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32"
      "--ro-bind-try /run/udev /run/udev"
    ];

  # Helper to create a sandboxed application module
  mkSandboxedApp =
    {
      config,
      lib,
      pkgs,
      inputs,
      optionName, # e.g. "steamSandboxed"
      packageName, # e.g. "steam-sandboxed"
      description,
      package, # e.g. pkgs.steam
      appId, # e.g. "com.valvesoftware.Steam"
      isFhsenv ? false,
      env ? { },
      sockets ? {
        x11 = true;
        wayland = true;
      },
      flatpak ? false,

      # Mounts
      mounts ? {
        read = [ ];
        readWrite = [ ];
      },

      # Bwrap/Fhsenv options
      fhsenvOpts ? {
        unshareUser = true;
        unshareUts = false;
        unshareCgroup = false;
        unsharePid = false;
        unshareNet = false;
        unshareIpc = false;
      },
      fhsenvExtra ? { }, # merged into fhsenv

      # Args
      baseArgs ? (mkCommonBindArgs { inherit config lib; }),
      additionalArgs ? [ ], # merged into fhsenv.bwrap.additionalArgs

      # DBus
      dbusProxy ? null, # { rules ? [], systemRules ? [], enableSystemBus ? false }
    }:
    let
      cfg = config.myModules.${optionName};
      bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;

      # Handle DBus Proxy Logic
      hasDbusProxy = dbusProxy != null;
      proxyScript =
        if hasDbusProxy then
          mkDbusProxyScript {
            inherit appId;
            enableSystemBus = dbusProxy.enableSystemBus or false;
            proxyArgs = dbusProxy.rules or [ ];
            systemProxyArgs = dbusProxy.systemRules or [ ];
          }
        else
          "";

      dbusBindArgs =
        if hasDbusProxy then
          [
            ''--bind "$XDG_RUNTIME_DIR/app/${appId}/bus" "$XDG_RUNTIME_DIR/bus"''
          ]
          ++ (
            if (dbusProxy.enableSystemBus or false) then
              [
                ''--bind "$XDG_RUNTIME_DIR/app/${appId}/bus_system" /run/dbus/system_bus_socket''
              ]
            else
              [ ]
          )
        else
          [ ];

    in
    {
      options.myModules.${optionName} = {
        enable = lib.mkEnableOption description;

        extraBindMounts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra paths to bind mount (read-write) into the sandbox";
        };
      };

      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = [
          (final: prev: {
            ${packageName} = bwrapperPkgs.mkBwrapper {
              app = {
                package = package;
                inherit isFhsenv;
                env = env;
                id = appId;
              };

              inherit sockets;
              flatpak.enable = flatpak;

              fhsenv = fhsenvExtra // {
                opts = fhsenvOpts;
                bwrap = {
                  baseArgs = lib.mkForce baseArgs;
                  additionalArgs = mkGuiBindArgs { } ++ additionalArgs ++ dbusBindArgs;
                };
              };

              mounts = {
                read = mkGuiMounts.read ++ mounts.read;
                readWrite = mounts.readWrite ++ cfg.extraBindMounts;
              };

              dbus.enable = false;

              script.preCmds.stage2 = proxyScript;
            };
          })
        ];

        environment.systemPackages = [ pkgs.${packageName} ];
      };
    };

in
{
  inherit
    mkDbusProxyScript
    mkCommonBindArgs
    mkGuiBindArgs
    mkGuiMounts
    mkGamingBindArgs
    mkSandboxedApp
    ;
}
