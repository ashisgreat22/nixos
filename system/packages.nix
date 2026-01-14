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
    prismlauncher-sandboxed
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
    fastfetch
    hyfetch
    nautilus
    lutris-sandboxed
    steam-sandboxed
    azahar-sandboxed
    faugus-sandboxed
    citron-sandboxed
    ryubing-sandboxed
    wireguard-tools
    jq
    grim
    vlc
    slurp
    wl-clipboard
    vesktop-sandboxed
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
    easyeffects
    dysk
    zstd
    podman
    spotify-sandboxed
    jmtpfs
    glfw
    mlocate
    openssl
    nspr
    firefox-sandboxed
    brave-sandboxed
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
  ];

  environment.variables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };
}
