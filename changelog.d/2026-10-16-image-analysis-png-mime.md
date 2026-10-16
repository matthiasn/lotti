### Fixed
- **Image analysis with Kimi K3 failed on screenshots and WebP pictures.**
  Every image was sent to the AI provider labelled as a JPEG, even when it was
  not one — a pasted screenshot is a PNG, and pictures from a pull request or
  the demo world are often WebP. Other models, such as GLM 5.3, ignored the
  wrong label, but Kimi K3 on Melious rejected the request as malformed, so
  the analysis stopped with a red error at the bottom of the task. Images are
  now labelled with the format they actually are, so Kimi K3 analyses them
  like any other picture.
