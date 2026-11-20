# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG VIBEMIS_VERSION="0.6.0"
ARG VIBEMIS_SHA256="142b56f089d943d0d43f7ad4d7856d268d1770c0f95e46dac92d01ecaf8b9141"
ARG VIBEMIS_URL="https://github.com/navyas321/vibemis/releases/download/${VIBEMIS_VERSION}/Vibemis-${VIBEMIS_VERSION}-x86_64.AppImage"

LABEL org.opencontainers.image.source="https://github.com/Joffrey-sama/vibemis" \
      org.opencontainers.image.title="vibemis-kiosk" \
      org.opencontainers.image.description="Hardware-accelerated Vibemis HDMI Kiosk (Xorg + Openbox + Intel VAAPI/Vulkan)" \
      org.opencontainers.image.version="${VIBEMIS_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    LIBVA_DRIVER_NAME=iHD \
    VDPAU_DRIVER_PATH=/tmp \
    XDG_RUNTIME_DIR=/tmp/runtime-vibemis \
    SDL_AUDIODRIVER=alsa \
    QT_QPA_PLATFORM=xcb

RUN apt-get update && apt-get install -y --no-install-recommends \
    alsa-utils \
    ca-certificates \
    curl \
    fontconfig \
    fonts-dejavu-core \
    intel-media-va-driver \
    kbd \
    libasound2t64 \
    libdrm2 \
    libegl1 \
    libfontconfig1 \
    libgbm1 \
    libgl1 \
    libgles2 \
    libharfbuzz0b \
    libinput10 \
    libopengl0 \
    libseat1 \
    libva-drm2 \
    libva-wayland2 \
    libva-x11-2 \
    libva2 \
    libwayland-client0 \
    libwayland-egl1 \
    libx11-xcb1 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xinerama0 \
    libxcb-xkb1 \
    libxkbcommon-x11-0 \
    libxkbcommon0 \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    openbox \
    python3 \
    udev \
    vainfo \
    x11-xserver-utils \
    xdotool \
    xinit \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xserver-xorg-video-intel \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Download, verify SHA256, and pre-extract the Vibemis AppImage so FUSE is not required at runtime.
RUN curl -fsSL "${VIBEMIS_URL}" -o /tmp/Vibemis.AppImage \
    && echo "${VIBEMIS_SHA256}  /tmp/Vibemis.AppImage" | sha256sum -c - \
    && chmod +x /tmp/Vibemis.AppImage \
    && /tmp/Vibemis.AppImage --appimage-extract \
    && mv /opt/squashfs-root /opt/vibemis \
    && rm -f /tmp/Vibemis.AppImage

COPY docker/merge_ini.py /usr/local/bin/merge_ini.py
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/merge_ini.py /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
