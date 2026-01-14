{
  pkgs,
  lib,
  ...
}:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat

    # CEF / Electron dependencies
    glib
    libgbm
    libglvnd
    nspr
    gtk3
    alsa-lib
    cups
    mesa
    libdrm
    libxkbcommon
    dbus
    libxml2

    # X11 / Wayland
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    xorg.libXScrnSaver
    pango
    cairo
    at-spi2-atk
    at-spi2-core
    systemd
  ];
}
