#!/usr/bin/env bash
# Fails when a library or helper in the unpacked archive at $1 links something
# the flatpak runtime in versions.env does not carry.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"
STAGE="$(cd "$1" && pwd)"
RUNTIME="org.freedesktop.Platform//$FLATPAK_RUNTIME"

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y --user --noninteractive flathub "$RUNTIME"

# flatpak needs a session bus, which a CI runner has none of
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$(mktemp -d)}"
missing="$(dbus-run-session -- flatpak run --filesystem="$STAGE" --command=sh "$RUNTIME" -c '
  cd "$0"
  for f in lib/*.so.* lib/wpe-webkit-2.0/injected-bundle/*.so libexec/wpe-webkit-2.0/*; do
    [ -L "$f" ] && continue
    LD_LIBRARY_PATH="$PWD/lib" ldd "$f" 2>/dev/null | grep "not found" | sed "s|^|$f: |"
  done
' "$STAGE")"

if [ -n "$missing" ]; then
  echo "$RUNTIME lacks:"
  echo "$missing"
  exit 1
fi
echo "every library resolves in $RUNTIME"
