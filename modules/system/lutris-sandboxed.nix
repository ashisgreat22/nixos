# Lutris Sandboxed with nix-bwrapper
# Provides a sandboxed Lutris with restricted permissions
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Apply the bwrapper overlay to get mkBwrapper
  bwrapperPkgs = pkgs.extend inputs.nix-bwrapper.overlays.default;
in
{
  # Provide the sandboxed Lutris package
  nixpkgs.overlays = [
    (final: prev: {
      lutris-sandboxed = bwrapperPkgs.mkBwrapper {
        app = {
          package = prev.lutris.override {
            extraPkgs = pkgs: [
              pkgs.curl
              pkgs.wget
              pkgs.gnutar
              pkgs.gzip
              pkgs.zstd
              pkgs.xz
              pkgs.p7zip
              pkgs.which
              pkgs.file
              pkgs.zenity
              pkgs.vulkan-loader
              pkgs.vulkan-tools
              pkgs.unzip
              pkgs.cabextract
              pkgs.xorg.xrandr
              pkgs.pciutils
              pkgs.gamemode.lib
              pkgs.xdg-utils
            ];
          };
          isFhsenv = true; # Lutris uses buildFHSEnv
          id = "net.lutris.Lutris";
          env = {
            WEBKIT_DISABLE_DMABUF_RENDERER = 1;
            APPIMAGE_EXTRACT_AND_RUN = 1;
            PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = "python";
            GTK_THEME = "catppuccin-mocha-blue-standard";
            BROWSER = "xdg-open";
            XDG_CURRENT_DESKTOP = "niri";
            XDG_SESSION_TYPE = "wayland";
            DBUS_SESSION_BUS_ADDRESS = "unix:path=$XDG_RUNTIME_DIR/bus";
            # Ensure Vulkan loader finds the drivers
            VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json:/run/opengl-driver-32/share/vulkan/icd.d/radeon_icd.i686.json";
          };
        };

        fhsenv = {
          skipExtraInstallCmds = false;
        };

        # Disable Flatpak emulation
        flatpak.enable = false;

        # Filesystem: Limited to Games directory
        mounts = {
          read = [
            "$HOME/.config/kdedefaults"
            "$HOME/.local/share/color-schemes"
            "$HOME/.local/share/Steam/compatibilitytools.d"
            # GTK Theming
            "$HOME/.config/gtk-3.0"
            "$HOME/.config/gtk-4.0"
            "$HOME/.icons"
          ];

          readWrite = [
            "$HOME/Games"
            "$HOME/.local/share/icons"
            "$HOME/.config/lutris"
            "$HOME/.local/share/lutris"
            "$HOME/.cache/lutris"
            "$HOME/.steam"
            "$HOME/.local/share/steam"
            "$HOME/.local/share/umu"
            "$HOME/.local/share/applications"
            "$HOME/.local/share/desktop-directories"
          ];
        };

        # Bind mount systemd-resolved socket directory to fix DNS
        # The sandbox mounts a tmpfs on /run, so we need to validly expose this
        fhsenv.bwrap.additionalArgs = [
          "--dir /run/systemd/resolve"
          "--ro-bind-try /run/systemd/resolve /run/systemd/resolve"
          # D-Bus session proxy
          ''--bind "$XDG_RUNTIME_DIR/app/net.lutris.Lutris/bus" "$XDG_RUNTIME_DIR/bus"''
          # D-Bus system proxy
          ''--bind "$XDG_RUNTIME_DIR/app/net.lutris.Lutris/bus_system" /run/dbus/system_bus_socket''
          # Wayland socket
          ''--bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"''
          # PipeWire + Pulse
          ''--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0"''
          ''--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse"''
          # Bind system themes to /usr/share
          "--ro-bind /run/current-system/sw/share/themes /usr/share/themes"
          "--ro-bind /run/current-system/sw/share/icons /usr/share/icons"
        ];

        # Disable built-in DBus module (invokes bwrap without --unshare-user)
        dbus.enable = false;

        # Manually set up DBus proxy with --unshare-user
        script.preCmds.stage2 = (import ./sandbox-utils.nix { inherit pkgs lib; }).mkDbusProxyScript {
          appId = "net.lutris.Lutris";
          enableSystemBus = true;
          proxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.Flatpak"''
            ''--talk="org.kde.StatusNotifierWatcher"''
            ''--talk="org.kde.KWin"''
            ''--talk="org.gnome.Mutter.DisplayConfig"''
            ''--talk="org.freedesktop.ScreenSaver"''
            ''--talk="org.freedesktop.portal.*"''
            ''--talk="org.freedesktop.secrets"''
            ''--talk="com.feralinteractive.GameMode"''
            ''--call="org.freedesktop.portal.*=*@/org/freedesktop/portal/desktop"''
            ''--own="net.lutris.Lutris"''
          ];
          systemProxyArgs = [
            "--filter"
            ''--talk="org.freedesktop.UDisks2"'' # Disk detection
          ];
        };
      };
    })
  ];
}
