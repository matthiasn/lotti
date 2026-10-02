### Added
- **Lotti for Linux as an AppImage.** Every release on GitHub now includes a
  `Lotti-<version>-x86_64.AppImage`: one file that runs on most Linux
  distributions from 2022 on, without Flathub and without installing anything.
  Download it, make it executable and start it. It brings its own media
  playback, recording, camera and keychain libraries, which the `tar.gz`
  download expects to be installed already. Before each release, CI starts it on
  Ubuntu 22.04 and 24.04, Debian 12 and Fedora.
