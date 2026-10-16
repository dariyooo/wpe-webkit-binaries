#!/usr/bin/env bash
# Installs what build.sh needs on Ubuntu 22.04.
set -euo pipefail

sudo apt-get update
# Runner images carry LLVM's libunwind-<n>-dev, which conflicts with the
# libunwind-dev GStreamer's headers pull in.
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y 'libunwind-*-dev' || true
# libjxl-dev is not in jammy, so JPEG XL is off in build.sh.
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential cmake ninja-build meson pkg-config ruby ruby-dev python3 \
  ccache gperf unifdef libglib2.0-dev libsoup-3.0-dev libssl-dev libgnutls28-dev \
  libsecret-1-dev libgcrypt20-dev libtasn1-dev libepoxy-dev libegl1-mesa-dev \
  libgles2-mesa-dev libxkbcommon-dev libjpeg-dev libpng-dev libwebp-dev \
  libharfbuzz-dev libharfbuzz-icu0 libfreetype6-dev libfontconfig1-dev \
  libicu-dev libxml2-dev libhyphen-dev libenchant-2-dev libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good libsqlite3-dev \
  libwoff-dev liblcms2-dev libatk1.0-dev \
  libatk-bridge2.0-dev libgbm-dev libdrm-dev libxslt1-dev libtool \
  libinput-dev libudev-dev libseat-dev libwayland-dev wayland-protocols \
  libseccomp-dev bubblewrap xdg-dbus-proxy \
  g++-12 libstdc++-12-dev
