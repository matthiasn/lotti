# AppImage packaging

Lotti is published for Linux in three forms:

| Form | Built by | Needs on the user's machine |
|------|----------|-----------------------------|
| Flathub | `flatpak/`, `flathub-release-pr.yml` | Flatpak |
| AppImage | this directory, `flutter-linux-appimage.yml` | glibc 2.35+, GTK 3, Mesa's GL, EGL and GLES, ALSA; FUSE to mount, or `--appimage-extract-and-run` without it |
| `linux.x64.tar.gz` | `flutter-linux-release.yml` | every library the app links (libmpv, libsecret, GStreamer, ...) |

An AppImage is a single executable file. It contains a compressed
filesystem with the app and the libraries it needs, plus a small runtime
that mounts the filesystem and starts `AppRun`. Users download it, mark it
executable and run it. There is no installation step, no app store and no
root access involved.

## Files

| File | Purpose |
|------|---------|
| `build_appimage.sh` | Turns the Flutter release bundle into `build/appimage/Lotti-<version>-<arch>.AppImage` and a `.sha256` file next to it. |
| `check_appimage.sh` | Checks a built AppImage on the current machine: bundle layout including the required GStreamer plugins, dependency resolution, and that the app is still running after a 30-second launch under Xvfb. |
| `lib.sh` | Helpers both scripts source: logging, the ELF test, and the parser and verifier for `gstreamer-plugins.txt`. |
| `AppRun` | Entry point inside the AppImage; sets up libmpv, GStreamer and `PATH`, then starts the Flutter binary. |
| `excludelist` | Libraries taken from the host instead of bundled. |
| `gstreamer-plugins.txt` | GStreamer plugins copied into the AppImage, and which code path needs each. |

## What goes into the AppImage

```
Lotti.AppDir/
├── AppRun
├── com.matthiasn.lotti.desktop -> usr/share/applications/…
├── com.matthiasn.lotti.png     -> usr/share/icons/hicolor/256x256/…
└── usr/
    ├── bin/          parecord, ffmpeg (audio recording runs `parecord | ffmpeg`)
    ├── lib/          bundled shared libraries, libmpv
    │   ├── gstreamer-1.0/   plugins and gst-plugin-scanner
    │   └── lotti/           the Flutter bundle, unchanged: lotti, lib/, data/
    └── share/        desktop entry, metainfo, icons
```

**Taken from the host:** everything in `excludelist` — glibc, libstdc++,
GTK 3 with GLib, Pango, Cairo and GDK-Pixbuf, graphics drivers (GL, EGL, GLES,
DRM, GBM), X11/Wayland, ALSA, D-Bus, systemd, fontconfig/freetype/harfbuzz.
Flutter's engine `dlopen()`s `libGLESv2.so.2` at startup, so OpenGL ES is a
hard requirement that neither `ldd` pass can see; every desktop that runs
GNOME or KDE has it, and the smoke test installs it explicitly. The
script follows `DT_NEEDED` from each bundled object to the next and stops at a
host-provided library, so whatever only host libraries pull in (the xcb
libraries Mesa links, say) stays on the host, where the host copy resolves it
anyway. A library that a bundled object links directly is bundled even when a
host library links it too, because its name can differ between distributions:
Ubuntu's `libjpeg.so.8` is `libjpeg.so.62` on Debian and Fedora. GTK and its
family are listed explicitly because the host's GTK loads the host's theme,
input-method, pixbuf and GIO modules, and those break against a bundled copy
of anything they bind to.

**Bundled:** everything else the bundle links (libsecret, keybinder,
GStreamer, libjsoncpp, ...). Three things that `ldd` cannot see are added
explicitly:

- **libmpv**, which media_kit loads with `dlopen()`. `AppRun` points
  `LIBMPV_LIBRARY_PATH` at it.
- **GStreamer plugins** for the runner's M4A-to-WAV conversion and for
  camera_desktop. `AppRun` points GStreamer at the bundled plugin directory
  only. `gstreamer-plugins.txt` says which code path needs each plugin;
  plugins marked `?` are optional, a missing required plugin fails the
  build, and `check_appimage.sh` fails on an AppImage that lacks one.
- **`parecord` and `ffmpeg`**, which `record_linux` runs as subprocesses.
  `AppRun` puts `usr/bin` first on `PATH`.

**How libraries are found:** each binary gets a RUNPATH relative to its own
location (`$ORIGIN`). For example, `lotti` gets `$ORIGIN/lib:$ORIGIN/..`, and
the plugins in `lotti/lib` get `$ORIGIN:$ORIGIN/../..`. `LD_LIBRARY_PATH` is
not set. Host programs that Lotti starts (browser, file manager) therefore keep
the host's libraries. After rewriting, the script runs `ldd` on every ELF file
and fails if anything is missing, or if a direct dependency that is not
host-provided would resolve to the host's copy instead of the bundled one.

## Building locally

The script uses the build machine's libraries, so the result runs only on
distributions whose glibc is at least as new as the build machine's. For a
release-quality build, use an Ubuntu 22.04 machine or container, as CI does.
On Debian/Ubuntu, the packages are (the last line is only for the launch
step of `check_appimage.sh`):

```bash
sudo apt-get install clang cmake make ninja-build pkg-config patchelf curl \
  libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev libjsoncpp-dev \
  libsqlite3-dev libkeybinder-3.0-dev libmpv-dev ffmpeg pulseaudio-utils \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav gstreamer1.0-pulseaudio \
  xvfb xauth dbus
```

Then:

```bash
make linux_appimage                     # flutter build linux + build_appimage.sh
linux/appimage/check_appimage.sh build/appimage/Lotti-*.AppImage
```

`build_appimage.sh --bundle DIR --output DIR --version VERSION` overrides the
defaults: `build/linux/<arch>/release/bundle`, `build/appimage`, and the
version from `pubspec.yaml`. It works on x86_64 and aarch64.

**The packing tools are pinned.** The script downloads `appimagetool` and the
AppImage runtime from tagged upstream releases into `build/appimage/tools/`
and stops unless each file matches the SHA-256 recorded at the top of
`build_appimage.sh`. The runtime is the first thing a user executes, so
neither comes from a `continuous` build. To move to a newer release, change
the version and the hashes together, taking the hashes from `sha256sum` of
the downloaded assets. `APPIMAGETOOL` and `APPIMAGE_RUNTIME` point at local
files to use as they are; `APPIMAGETOOL_URL` and `APPIMAGE_RUNTIME_URL` change
where the pinned versions are downloaded from, and what arrives is still
checked against the hash.

`check_appimage.sh` needs `xvfb-run` and `dbus-run-session` to launch the app.
`--no-launch` limits it to the layout and dependency checks. On a machine with
Lotti's build dependencies installed, those checks can pass even with a library
missing from the AppImage, because `ldd` then finds the host's copy. The check
is meant for clean machines.

## CI

`.github/workflows/flutter-linux-appimage.yml` runs on every tag (except
`play/**`), on pull requests that touch `linux/**`, `pubspec.lock` (where a
dependency with a new native library first shows up) or the workflow, and on
manual dispatch:

1. **build** runs in an `ubuntu:22.04` container, builds the release
   bundle and the AppImage, and uploads both as the `lotti-appimage-x86_64`
   workflow artifact. Pull requests can test that artifact before anything is
   released.
2. **smoke-test** runs `check_appimage.sh` in clean `ubuntu:22.04`,
   `ubuntu:24.04`, `debian:12` and `fedora:latest` containers. These have only
   GTK 3, Mesa (GL, EGL, GLES and the software rasteriser), ALSA and Xvfb
   installed.
3. **publish** (pushed tags only; a manual run never publishes, even on a
   tag) attaches the `.AppImage` and its `.sha256` to the tag's GitHub
   release. `flutter-linux-release.yml` uploads the `tar.gz` to the same
   release.

## Known limitations

- **x86_64 only in CI.** The scripts support aarch64, but the workflow does
  not build it yet.
- **No self-update.** The AppImage carries no AppImageUpdate information
  yet, so users download new versions from Releases themselves.
- **No sandbox.** Unlike the Flatpak, the AppImage runs with the user's full
  permissions. Lotti detects the Flatpak through `FLATPAK_ID` and `/app`,
  neither of which exists here, so it uses its direct (non-portal) code paths.
- **Keychain.** libsecret is bundled, but storing Matrix credentials still
  needs a Secret Service on the desktop (GNOME Keyring, KWallet, KeePassXC).
- **Environment of child processes.** The `GST_*` and `LIBMPV_LIBRARY_PATH`
  variables from `AppRun` are inherited by programs Lotti starts. A host
  GStreamer application opened from Lotti would look for plugins in the
  AppImage.
- **Local transcription with whisper.cpp** is not bundled. The
  `feat/whisper-cpp-flatpak` work has not been merged; once it is,
  `whisper-server` can go into `usr/bin`.

The release flow this lane belongs to is described in
[platform targets, CI and release](../../knowledge/architecture/platform-and-release.md).
