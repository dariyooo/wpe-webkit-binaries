#!/usr/bin/env bash
# Builds libwpe, the FDO backend and WPE WebKit into $PREFIX (/opt/wpe).
#
# Run install_deps.sh first. Sources land in $SRC_DIR, and every step skips
# what an earlier run already did, so a build that was stopped continues.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"

PREFIX="${PREFIX:-/opt/wpe}"
SRC_DIR="${SRC_DIR:-$HOME/src}"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# WebKit wants GCC 12.2+; jammy defaults to 11.4, whose libstdc++ has no
# std::optional::transform. clang-18 does not help: it picks up that same
# libstdc++ and fails deep into WebCore.
export CC=/usr/bin/gcc-12 CXX=/usr/bin/g++-12

# WebCore's unified sources take 2-3 GB each to compile, so a full-width build
# runs the machine out of memory and gcc dies with "Killed signal terminated
# program cc1plus".
JOBS="${JOBS:-$(( $(free -g | awk '/^Mem:/{print $2}') / 4 ))}"
[ "$JOBS" -lt 1 ] && JOBS=1
[ "$JOBS" -gt "$(nproc)" ] && JOBS="$(nproc)"

fetch() { # <name> <url> <sha256>
  local archive
  archive="$SRC_DIR/$(basename "$2")"
  [ -f "$archive" ] || curl -fsSL -o "$archive" "$2"
  echo "$3  $archive" | sha256sum -c --quiet
  [ -d "$SRC_DIR/$1" ] || tar -xf "$archive" -C "$SRC_DIR"
}

mkdir -p "$SRC_DIR" "$PREFIX"

fetch "libwpe-$LIBWPE_VERSION" \
  "https://wpewebkit.org/releases/libwpe-$LIBWPE_VERSION.tar.xz" "$LIBWPE_SHA256"
fetch "wpebackend-fdo-$WPEBACKEND_FDO_VERSION" \
  "https://wpewebkit.org/releases/wpebackend-fdo-$WPEBACKEND_FDO_VERSION.tar.xz" "$WPEBACKEND_FDO_SHA256"
fetch "wpewebkit-$WPE_VERSION" \
  "https://wpewebkit.org/releases/wpewebkit-$WPE_VERSION.tar.xz" "$WPE_SHA256"

cd "$SRC_DIR/libwpe-$LIBWPE_VERSION"
[ -f build/build.ninja ] || cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_DOCS=OFF
ninja -C build install

cd "$SRC_DIR/wpebackend-fdo-$WPEBACKEND_FDO_VERSION"
# meson puts libraries in lib/<triplet> on Debian whatever the prefix, unless told
[ -f build/build.ninja ] || meson setup build \
  --buildtype=release \
  --prefix="$PREFIX" \
  --libdir=lib
ninja -C build install

cd "$SRC_DIR/wpewebkit-$WPE_VERSION"

# A release build resolves the helper processes against PKGLIBEXECDIR alone,
# which is fixed when WPE is configured. An app that is unpacked somewhere new on
# every run, like an AppImage, keeps its helpers elsewhere, so let the env var
# and the next-to-the-binary lookup compile in; both already fall through to
# PKGLIBEXECDIR when they find nothing.
python3 - <<'PATCH'
p = "Source/WebKit/Shared/glib/ProcessExecutablePathGLib.cpp"
s = open(p).read()
guard = "#if ENABLE(DEVELOPER_MODE)"
marker = "// always honour WEBKIT_EXEC_PATH"
if marker not in s:
    # one guard around getExecutablePath, one around the two lookups
    assert s.count(guard) == 2, "the developer-mode guards in " + p + " changed"
    s = s.replace(guard, "#if 1 " + marker)
    open(p, "w").write(s)
    print("patched findWebKitProcess")
PATCH

# DRM needs libdrm 2.4.114 for drmModeCreateDumbBuffer; jammy has 2.4.113. The
# webview renders headless, so the DRM platform is not built.
#
# The flatpak runtime has no libavif, so AVIF is off.
[ -f build/build.ninja ] || cmake -S . -B build -G Ninja \
  -DPORT=WPE \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DENABLE_WPE_PLATFORM=ON \
  -DENABLE_WPE_PLATFORM_DRM=OFF \
  -DUSE_JPEGXL=OFF \
  -DUSE_AVIF=OFF \
  -DENABLE_SPEECH_SYNTHESIS=OFF \
  -DUSE_LIBBACKTRACE=OFF \
  -DENABLE_DOCUMENTATION=OFF \
  -DENABLE_INTROSPECTION=OFF \
  -DENABLE_MINIBROWSER=OFF \
  -DENABLE_JOURNALD_LOG=OFF
ninja -C build -j"$JOBS"
ninja -C build install

echo "WPE $(pkg-config --modversion wpe-webkit-2.0) installed to $PREFIX"
