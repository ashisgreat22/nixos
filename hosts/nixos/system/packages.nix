{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Rust System Rewrites
    mimalloc # Fast allocator
    grc # Generic Colouriser
    mold # Fast linker
    skim # Rust fuzzy finder (fzf alternative)
    uutils-coreutils-noprefix # GNU coreutils replacement
    ripgrep # grep replacement
    eza # ls replacement
    bat # cat replacement
    fd # find replacement
    procs # ps replacement
    dust # du replacement
    sd # sed replacement
    bottom # top replacement
    zoxide # cd replacement
    yazi # file manager
    tokei # code statistics
    hyperfine # benchmarking

    slirp4netns # Better network backend than slirp4netns for rootless containers
    neovim
    wget
    kitty
    quickshell
    git
    sbctl
    fuzzel
    # prismlauncher-sandboxed # Managed by System Module
    polychromatic
    vscodium
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    jdk
    antigravity
    onlyoffice-desktopeditors
    python3
    swww
    claude-code
    lxqt.lxqt-policykit
    (catppuccin-gtk.override { variant = "mocha"; })
    catppuccin-kvantum
    catppuccin
    nwg-look
    chromium
    qt6Packages.qt6ct
    libsForQt5.qt5ct
    kdePackages.qtstyleplugin-kvantum
    goverlay
    mangohud
    gamemode
    lact
    umu-launcher
    steam-run
    fastfetch
    hyfetch
    nautilus
    # lutris-sandboxed # Added by module
    # steam-sandboxed # Added by module
    # azahar-sandboxed # Added by module
    # faugus-sandboxed # Added by module
    # citron-sandboxed # Added by module
    # ryubing-sandboxed # Added by module
    wireguard-tools
    jq
    grim
    vlc
    slurp
    wl-clipboard
    # vesktop-sandboxed # Added by module
    starship
    zip
    unzip
    unar
    p7zip
    nixfmt
    tealdeer
    uv
    nodejs
    sillytavern
    btop
    distrobox
    heroic
    tcpdump
    codex
    distroshelf
    gemini-cli
    wineWow64Packages.waylandFull
    qbittorrent
    stress-ng
    kdePackages.kleopatra
    kdePackages.ark
    qdirstat
    dysk
    zstd
    podman
    # spotify-sandboxed # Added by module
    jmtpfs
    glfw
    mlocate
    openssl
    nspr
    # firefox-sandboxed # Added by module
    # tutanota-sandboxed # Added by module
    # brave-sandboxed # Imported via module, wrapper provided there
    eddie
    appimage-run
    rivalcfg
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    clinfo
    playerctl
    dotnet-sdk_9
    xdelta
    xxd
    winetricks
    protontricks
    file
    ffmpeg-full
    gsettings-desktop-schemas
    glib
    gtk3
    gtk4
  ];

  programs.dconf.enable = true;

  environment.variables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };
}
