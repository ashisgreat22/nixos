FROM archlinux:latest

# Update system and install dependencies
# wayland, kitty, fonts, coreutils, curl, iputils
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    kitty \
    wayland \
    mesa \
    vulkan-intel \
    vulkan-radeon \
    noto-fonts \
    noto-fonts-emoji \
    noto-fonts-cjk \
    ttf-jetbrains-mono \
    ttf-dejavu \
    bash \
    base-devel \
    git \
    coreutils \
    curl \
    iputils \
    libpulse \
    pipewire \
    sudo \
    starship \
    eza \
    git \
    hyfetch \
    fastfetch \
    && pacman -Scc --noconfirm

# Create non-root user 'arch-user' (matching typical UID 1000)
RUN useradd -m -u 1000 -s /bin/bash arch-user && \
    echo "arch-user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/arch-user

# Switch to user to build yay
USER arch-user
WORKDIR /home/arch-user

# Install yay AUR helper
RUN cd /tmp && \
    git clone https://aur.archlinux.org/yay.git && \
    cd yay && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -rf yay

# Hardening: Set password to 'arch' and remove NOPASSWD for runtime security
USER root
RUN echo "arch-user:arch" | chpasswd && \
    sed -i 's/NOPASSWD: //g' /etc/sudoers.d/arch-user
USER arch-user

# Ensure .config/kitty exists
RUN mkdir -p /home/arch-user/.config/kitty

ENV MOZ_ENABLE_WAYLAND=1
ENV XDG_RUNTIME_DIR=/tmp

CMD ["kitty"]
