### Fixed
- **The Link button in "Link a pull request" no longer breaks out of its
  field.** Once you had typed something, the button stretched over the
  field's highlighted border and left a mismatched corner beside it. It now
  sits inside the field with the border running unbroken around it, and the
  progress that replaces it while linking stays on the same spot.

### Changed
- **"Link a pull request" says things once.** The field's label now names
  both forms it takes — a URL or `owner/repo#123` — instead of a label, a
  helper line and a paragraph each saying part of it. When the task's
  category has no repository, the one hint about picking from open pull
  requests sits directly under the field.
