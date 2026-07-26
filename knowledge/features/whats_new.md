---
type: Feature Module
title: What's New
description: Remote release notes with local gating — fetched from the docs repo, filtered by installed version, shown at most once per version.
resource: ../../lib/features/whats_new
tags: [whats-new, releases, remote-content]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:00:00Z }
stale_after: 2027-03-08
sources:
  - id: src
    resource: ../../lib/features/whats_new
    title: What's New source
    last_modified: 2026-07-26
---

What's New turns release notes into an in-app editorial surface instead of a
changelog nobody opens twice.

Its runtime job is narrow: fetch release metadata and markdown from the docs
repository, **keep only releases not newer than the installed app version**,
remember which releases this device has already seen, and optionally auto-open
the modal **once per installed app version**.

**This is remote content with local gating.** The content lives in the docs
repository; the "should this device still show this?" decision lives in app state
and device preferences.

Two consequences follow from that split:

- **A release newer than the installed build is never shown.** Filtering by
  installed version is what stops a user reading about features they do not have.
- **Seen-state is per device**, not synced. Reading the notes on a laptop does not
  suppress them on a phone, which is the right default for a per-install
  announcement.

The auto-open budget is per installed version, so upgrading re-arms it exactly
once.
