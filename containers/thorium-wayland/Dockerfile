FROM --platform=linux/amd64 docker.io/library/debian:trixie-slim

# Install dependencies for Thorium
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    wget \
    xz-utils \
    ca-certificates \
    libgtk-3-0 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpulse0 \
    libpango-1.0-0 \
    libcairo2 \
    libdbus-1-3 \
    libexpat1 \
    libxext6 \
    libxfixes3 \
    libx11-6 \
    libxcb1 \
    libatspi2.0-0 \
    fonts-noto \
    fonts-dejavu-core \
    unzip \
    xdg-utils \
    libegl1 \
    libgl1 \
    libgles2 \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Catppuccin Mocha GTK Theme
RUN mkdir -p /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark && \
    wget -O /tmp/theme.zip https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-blue-standard+default.zip && \
    unzip /tmp/theme.zip -d /usr/share/themes/ && \
    mv /usr/share/themes/catppuccin-mocha-blue-standard+default/* /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark/ && \
    rm -rf /tmp/theme.zip /usr/share/themes/catppuccin-mocha-blue-standard+default

# Create non-root user
RUN useradd -m -s /bin/bash thorium-user

# Download and install Thorium (AVX2)
# Using specific version to ensure stability, can be updated later
RUN wget -O /tmp/thorium.deb "https://github.com/Alex313031/Thorium/releases/download/M128.0.6613.189/thorium-browser_128.0.6613.189_AVX2.deb" && \
    apt-get update && \
    apt-get install -y /tmp/thorium.deb && \
    rm /tmp/thorium.deb && \
    rm -rf /var/lib/apt/lists/*

# Create settings.ini to enforce theme
RUN mkdir -p /home/thorium-user/.config/gtk-3.0 && \
    echo -e "[Settings]\ngtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark\ngtk-application-prefer-dark-theme=1" > /home/thorium-user/.config/gtk-3.0/settings.ini && \
    chown -R thorium-user:thorium-user /home/thorium-user/.config

USER thorium-user
WORKDIR /home/thorium-user

# Thorium flags for Wayland and features
CMD ["thorium-browser", "--ozone-platform=wayland", "--enable-features=UseOzonePlatform", "--enable-gpu-rasterization", "--enable-zero-copy"]
