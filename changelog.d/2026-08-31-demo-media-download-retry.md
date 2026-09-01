### Fixed
- **Demo-mode cover images could stay missing after switching the demo on.**
  The demo world's photos are fetched from a public bucket that sometimes
  answers a request with "too many requests", and one refused download used
  to leave that cover as a placeholder until the next app start. Each download
  now retries a few times with a short, growing pause, so the covers fill in
  during the same session.
