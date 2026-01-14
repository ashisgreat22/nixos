{ pkgs, lib }:
{
  # Generates the shell script content to set up xdg-dbus-proxy inside a bwrap user namespace.
  # This is used for sandboxed apps that run with unshareUser = true.
  mkDbusProxyScript = { 
    appId,                                      # Unique ID for the app (e.g. "org.mozilla.firefox")
    proxyArgs,                                  # Arguments for xdg-dbus-proxy (session bus). Can be string or list.
    socketPath ? "$XDG_RUNTIME_DIR/app/${appId}/bus",
    upstreamSocket ? "$XDG_RUNTIME_DIR/bus",
    enableSystemBus ? false,
    systemProxyArgs ? "",                       # Arguments for xdg-dbus-proxy (system bus). Can be string or list.
    systemSocketPath ? "$XDG_RUNTIME_DIR/app/${appId}/bus_system",
    systemUpstreamSocket ? "/run/dbus/system_bus_socket"
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
    systemFunc = if enableSystemBus 
                 then mkProxyFunc "set_up_system_dbus_proxy" systemUpstreamSocket systemSocketPath sArgs true
                 else "";
    
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
        ${if enableSystemBus then ''
        if ! kill -0 "$PID_SYSTEM" 2>/dev/null;
        then
          echo "Error: System D-Bus proxy (PID $PID_SYSTEM) died unexpectedly." >&2
          exit 1
        fi
        '' else ""}

        # Check for sockets
        if [ -S "${socketPath}" ]${if enableSystemBus then " && [ -S \"${systemSocketPath}\" ]" else ""};
        then
          break
        fi
        ${coreutils}/sleep 0.02
      done
    '';

  in ''
    ${sessionFunc}
    ${systemFunc}

    set_up_dbus_proxy &
    PID_SESSION=$!
    ${if enableSystemBus then ''
    set_up_system_dbus_proxy &
    PID_SYSTEM=$!
    '' else ""}
    
    ${waitLoop}
  '';
}