FROM debian:trixie-slim

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Firefox and dependencies
# We use firefox-esr as it is the standard in Debian
# mesa-utils, libgl1-mesa-dri, libglx-mesa0 for AMD GPU support
# wayland support packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    firefox-esr \
    mesa-utils \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libwayland-client0 \
    libwayland-egl1 \
    wayland-protocols \
    pulseaudio \
    libpulse0 \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-dejavu \
    dbus \
    dbus-x11 \
    libdbus-glib-1-2 \
    libxtst6 \
    libgtk-3-0 \
    libx11-xcb1 \
    libpci3 \
    libvulkan1 \
    mesa-vulkan-drivers \
    ca-certificates \
    wget \
    unzip \
    gnome-themes-extra \
    adwaita-icon-theme \
    gsettings-desktop-schemas \
    && rm -rf /var/lib/apt/lists/*

# Install Catppuccin Mocha GTK Theme
RUN mkdir -p /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark && \
    wget -qO /tmp/theme.zip https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-blue-standard+default.zip && \
    unzip -q /tmp/theme.zip -d /usr/share/themes/ && \
    mv /usr/share/themes/catppuccin-mocha-blue-standard+default/* /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark/ && \
    rm -rf /tmp/theme.zip /usr/share/themes/catppuccin-mocha-blue-standard+default

# Create non-root user
RUN useradd -m -s /bin/bash firefox-user

# Establish GTK settings
RUN mkdir -p /home/firefox-user/.config/gtk-3.0 && \
    printf "[Settings]\ngtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark\ngtk-application-prefer-dark-theme=1\n" > /home/firefox-user/.config/gtk-3.0/settings.ini && \
    chown -R firefox-user:firefox-user /home/firefox-user/.config

# Setup directories for runtime
RUN mkdir -p /run/user/1000 && chown firefox-user:firefox-user /run/user/1000

USER firefox-user
WORKDIR /home/firefox-user

# Set environment variables for Wayland
ENV MOZ_ENABLE_WAYLAND=1
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV GTK_THEME=Catppuccin-Mocha-Standard-Blue-Dark

CMD ["dbus-run-session", "firefox-esr", "--new-instance", "--allow-downgrade"]
