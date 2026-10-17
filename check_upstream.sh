#!/usr/bin/env bash
# Moves versions.env to the newest stable WPE WebKit, libwpe and WPEBackend-fdo
# on wpewebkit.org. Writes changed=1 to $GITHUB_OUTPUT when one moved.
#
# WebKit numbers its development snapshots with an odd minor (2.53.x) and the
# betas of the next stable with a patch of 90 or more (2.53.92), so both are
# skipped.
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=versions.env
source versions.env
listing="$(curl -fsSL https://wpewebkit.org/releases/)"
changed=0

newest() { # <name>
  grep -o -E "$1-[0-9]+\.[0-9]+\.[0-9]+\.tar\.xz" <<<"$listing" \
    | sed -E "s/^$1-(.*)\.tar\.xz$/\1/" | sort -uV \
    | awk -F. '$2 % 2 == 0 && $3 < 90' | tail -1
}

update() { # <variable prefix> <name>
  local current_var="${1}_VERSION" version sha
  version="$(newest "$2")"
  [ -n "$version" ] || { echo "no stable $2 release on wpewebkit.org" >&2; exit 1; }
  [ "${!current_var}" = "$version" ] && return
  sha="$(curl -fsSL "https://wpewebkit.org/releases/$2-$version.tar.xz.sums" | awk '/sha256sum:/ {print $2}')"
  [ -n "$sha" ] || { echo "no sha256 for $2 $version" >&2; exit 1; }
  sed -i.bak -E "s/^${1}_VERSION=.*/${1}_VERSION=$version/; s/^${1}_SHA256=.*/${1}_SHA256=$sha/" versions.env
  rm versions.env.bak
  echo "$2: ${!current_var} -> $version"
  changed=1
}

update WPE wpewebkit
update LIBWPE libwpe
update WPEBACKEND_FDO wpebackend-fdo
echo "changed=$changed" >> "${GITHUB_OUTPUT:-/dev/null}"
