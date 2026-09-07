### Fixed
- **Audio transcription could fail on Android devices that use 16 KB memory
  pages.** Lotti encodes a recording to MP3 before sending it off to be
  transcribed, and that encoder was still built for the older 4 KB memory
  layout — which newer 64-bit Android devices refuse to load at all. Every
  native library Lotti bundles for 64-bit Android is now built for 16 KB
  pages, so transcription works on current hardware again.

### Changed
- **The Android download is around 4 MB smaller.** Lotti no longer ships its
  own copy of OpenSSL. The encryption it was there for now comes from the
  Matrix package directly, so that library — and the C++ runtime it pulled
  along with it — are gone.
