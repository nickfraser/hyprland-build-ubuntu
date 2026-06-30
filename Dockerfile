FROM ubuntu:24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG PREFIX=/opt/hyprland
ARG PROFILE=profiles/desktop.list
ARG VERSION_FILE=versions/latest.env
ARG CC=gcc-14
ARG CXX=g++-14

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bash \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    curl \
    file \
    g++-14 \
    gcc-14 \
    git \
    hwdata \
    libabsl-dev \
    libcairo2-dev \
    libdbusmenu-gtk3-dev \
    libdisplay-info-dev \
    libdrm-dev \
    libegl1-mesa-dev \
    libfmt-dev \
    libgbm-dev \
    glslang-dev \
    glslang-tools \
    libgles2-mesa-dev \
    libgtk-layer-shell-dev \
    libgtkmm-3.0-dev \
    libheif-dev \
    libiniparser-dev \
    libinput-dev \
    libjpeg-dev \
    libjsoncpp-dev \
    libjxl-dev \
    liblcms2-dev \
    libmagic-dev \
    libmuparser-dev \
    libopengl-dev \
    libpango1.0-dev \
    libpam0g-dev \
    libpipewire-0.3-dev \
    libpixman-1-dev \
    libpng-dev \
    libpugixml-dev \
    libre2-dev \
    librsvg2-dev \
    libsdbus-c++-dev \
    libseat-dev \
    libsigc++-2.0-dev \
    libspa-0.2-dev \
    libspdlog-dev \
    libsystemd-dev \
    libtomlplusplus-dev \
    libudev-dev \
    libuuid1 \
    libwayland-dev \
    libwebp-dev \
    libxcb-composite0-dev \
    libxcb-icccm4-dev \
    libxcb-render0-dev \
    libxcb-res0-dev \
    libxcb-xfixes0-dev \
    libxcb1-dev \
    libxcursor-dev \
    libxkbcommon-dev \
    libzip-dev \
    lld \
    libtool \
    libtool-bin \
    m4 \
    meson \
    ninja-build \
    pkg-config \
    python-is-python3 \
    python3 \
    scdoc \
    uuid-dev \
    xcb-proto \
    xutils-dev \
    wayland-protocols && \
    rm -rf /var/lib/apt/lists/*

RUN printf '%s\n' \
    'prefix=/usr' \
    'includedir=${prefix}/include/iniparser' \
    'libdir=${prefix}/lib/x86_64-linux-gnu' \
    '' \
    'Name: iniparser' \
    'Description: iniparser library for parsing INI files' \
    'Version: 4.2.1' \
    'Libs: -L${libdir} -liniparser' \
    'Cflags: -I${includedir}' \
    > /usr/share/pkgconfig/iniparser.pc

RUN curl -fsSL https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-x86_64.tar.gz \
    | tar xz -C /opt && \
    ln -sf /opt/cmake-3.31.6-linux-x86_64/bin/cmake /usr/local/bin/cmake && \
    ln -sf /opt/cmake-3.31.6-linux-x86_64/bin/ctest /usr/local/bin/ctest

WORKDIR /workspace
COPY . /workspace

ENV CC=${CC}
ENV CXX=${CXX}

RUN PREFIX="${PREFIX}" PROFILE_FILE="${PROFILE}" VERSION_FILE="${VERSION_FILE}" scripts/build-in-container.sh

FROM ubuntu:24.04 AS artifact
COPY --from=build /out/ /out/
