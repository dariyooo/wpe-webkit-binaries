# WPE WebKit binaries

Prebuilt [WPE WebKit](https://wpewebkit.org) for Linux, x64 and arm64, with
libwpe and WPEBackend-fdo. Built for `flutter_inappwebview_linux`, which needs WPE 2.40 or newer, a
version no Ubuntu release packages.

One archive per architecture works on Ubuntu 22.04 and later and inside the
`org.freedesktop.Platform` flatpak runtime named in `versions.env`, which CI
checks on every build.

## Using an archive

```bash
tar -xf wpe_webkit_linux_x64.tar.xz
export PKG_CONFIG_PATH="$PWD/wpe_webkit_linux_x64/lib/pkgconfig"
```

At runtime WPE needs its helper processes and injected bundle:

```bash
export LD_LIBRARY_PATH="<dir>/lib"
export WEBKIT_EXEC_PATH="<dir>/libexec/wpe-webkit-2.0"
export WEBKIT_INJECTED_BUNDLE_PATH="<dir>/lib/wpe-webkit-2.0/injected-bundle"
```

## Building

`versions.env` names what is built. The **Build WPE WebKit** workflow builds
both architectures and publishes them as the release `wpe-webkit-<version>`,
replacing the files of an existing release of that version. A build that runs
out of time keeps its compiler cache; run it again and it continues.

Locally, on Ubuntu 22.04:

```bash
./install_deps.sh
sudo mkdir -p /opt/wpe && sudo chown "$USER" /opt/wpe
./build.sh && ./package.sh
```

## License

WPE WebKit, libwpe and WPEBackend-fdo are LGPL and BSD licensed; the scripts
here and the source links in each release are how these binaries are built.
The only change to WebKit, in `build.sh`, makes a release build honour
`WEBKIT_EXEC_PATH`.
