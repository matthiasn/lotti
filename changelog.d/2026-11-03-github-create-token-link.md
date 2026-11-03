### Added
- **Connecting GitHub no longer means hunting for the right token settings.**
  Settings → Advanced Settings → GitHub has a "Create a token on GitHub"
  button that opens GitHub's token form with Lotti's name, a one-year expiry
  and the read-only pull request and commit status permissions already
  filled in. Choose your repositories, create the token and paste it back.
  If your browser cannot be opened, the page says where on github.com to make
  the token by hand.
- **Connecting and disconnecting GitHub now confirm themselves.** A toast says
  "Connected to GitHub as @you" once the token is stored, and "Disconnected
  from GitHub" once it is removed, and Connect shows a spinner while GitHub is
  asked.

### Fixed
- **Connecting GitHub could hang with no word when the device would not store
  the token.** GitHub accepted it, the keychain refused to save it, and the
  page sat there with Connect greyed out. It now says the token could not be
  stored and lets you try again; a disconnection the device refuses is said
  too, instead of failing silently.
