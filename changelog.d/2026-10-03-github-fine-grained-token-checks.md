### Fixed
- **Pull requests in private repositories now refresh with a fine-grained
  GitHub token.** GitHub does not let fine-grained tokens read check runs, so
  in a private repository every refresh — and every attempt to link a pull
  request — failed with "not allowed". Lotti now reads everything else and
  counts CI from commit statuses, and the card says CI may be incomplete
  instead of claiming it passes. The GitHub settings page now names the two
  permissions to grant, "Pull requests" and "Commit statuses", both read-only.
