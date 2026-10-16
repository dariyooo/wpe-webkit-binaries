#!/usr/bin/env bash
# Packs what build.sh installed into wpe_webkit_linux_<arch>.tar.xz in $OUT_DIR.
#
# The archive unpacks anywhere: the pkg-config files point at their own folder,
# and the libraries the flatpak runtime and newer distros lack (ICU, libjpeg)
# ship beside WPE. ICU's symbols carry its major version, so the bundled copy
# lives next to any other ICU without clashing.
set -euo pipefail

PREFIX="${PREFIX:-/opt/wpe}"
OUT_DIR="${OUT_DIR:-$PWD/out}"

case "$(uname -m)" in
  x86_64) ARCH=x64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac
NAME="wpe_webkit_linux_$ARCH"
STAGE="$OUT_DIR/$NAME"

rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -a "$PREFIX/include" "$PREFIX/lib" "$PREFIX/libexec" "$PREFIX/share" "$STAGE/"
rm -rf "$STAGE/share/doc" "$STAGE/share/man"

while read -r soname path; do
  cp -L "$path" "$STAGE/lib/$soname"
  echo "bundled $soname from $path"
done < <(ldd "$STAGE/lib/libWPEWebKit-2.0.so.1" | awk '/libicu|libjpeg/ {print $1, $3}')

sed -i "s|$PREFIX|\${pcfiledir}/../..|g" "$STAGE"/lib/pkgconfig/*.pc

find "$STAGE/lib" "$STAGE/libexec" -type f -exec sh -c \
  'file -b "$1" | grep -q "^ELF" && strip --strip-unneeded "$1"' _ {} \;

XZ_OPT=-T0 tar -C "$OUT_DIR" -cJf "$OUT_DIR/$NAME.tar.xz" "$NAME"
echo "packed $OUT_DIR/$NAME.tar.xz ($(du -h "$OUT_DIR/$NAME.tar.xz" | cut -f1))"
