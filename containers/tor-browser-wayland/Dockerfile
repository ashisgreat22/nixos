FROM --platform=linux/amd64 docker.io/library/debian:trixie-slim

# Install dependencies for Tor Browser
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    wget \
    xz-utils \
    libgtk-3-0 \
    libdbus-glib-1-2 \
    libxt6 \
    libasound2 \
    libpulse0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxtst6 \
    libxcursor1 \
    libgl1 \
    libegl1 \
    fonts-noto \
    fonts-dejavu-core \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Catppuccin Mocha GTK Theme (consistency with Firefox)
RUN mkdir -p /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark && \
    wget -O /tmp/theme.zip https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-blue-standard+default.zip && \
    unzip /tmp/theme.zip -d /usr/share/themes/ && \
    mv /usr/share/themes/catppuccin-mocha-blue-standard+default/* /usr/share/themes/Catppuccin-Mocha-Standard-Blue-Dark/ && \
    rm -rf /tmp/theme.zip /usr/share/themes/catppuccin-mocha-blue-standard+default

# Create non-root user
RUN useradd -m -s /bin/bash tor-user

# Download and install Tor Browser (fetches latest stable version)
RUN TB_VERSION=$(wget -qO- "https://www.torproject.org/download/" | \
    sed -n 's/.*\/dist\/torbrowser\/\([0-9.]*\)\/tor-browser-linux.*/\1/p' | \
    head -1) && \
    if [ -z "$TB_VERSION" ]; then TB_VERSION="15.0.3"; fi && \
    echo "Installing Tor Browser version: $TB_VERSION" && \
    wget -O /tmp/tor.tar.xz "https://www.torproject.org/dist/torbrowser/${TB_VERSION}/tor-browser-linux-x86_64-${TB_VERSION}.tar.xz" && \
    cd /home/tor-user && \
    tar -xJf /tmp/tor.tar.xz && \
    rm /tmp/tor.tar.xz && \
    chown -R tor-user:tor-user /home/tor-user

# Create settings.ini to enforce theme
RUN mkdir -p /home/tor-user/.config/gtk-3.0 && \
    echo -e "[Settings]\ngtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark\ngtk-application-prefer-dark-theme=1" > /home/tor-user/.config/gtk-3.0/settings.ini && \
    chown -R tor-user:tor-user /home/tor-user/.config

USER tor-user
WORKDIR /home/tor-user

# Tor Browser uses its own profile directory within the bundle
ENV MOZ_ENABLE_WAYLAND=1

CMD ["/home/tor-user/tor-browser/Browser/start-tor-browser"]
