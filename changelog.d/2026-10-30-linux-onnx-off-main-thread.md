### Fixed
- **Reading aloud on Linux no longer freezes the app.** On-device speech was
  synthesized on the thread that draws the window, so the app stopped
  responding for as long as each sentence took to prepare. It now runs in the
  background, as it already did on macOS.
