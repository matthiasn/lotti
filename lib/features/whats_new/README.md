# What's New

What's New shows release notes inside the app, so a user who just updated can see
what changed without hunting for a changelog.

## What it does for the user

- **Shows what actually shipped**, as readable notes rather than a raw commit
  list.
- **Never shows the future.** Releases newer than the installed build are filtered
  out, so nobody reads about a feature they do not have yet.
- **Appears once per version.** After an update it opens itself once, then stays
  out of the way.
- **Remembers what was read** on this device, and can always be reopened from
  Settings.

The notes themselves come from the docs repository, so they can be improved
without shipping an app update.

## What it owns

Fetching release metadata and markdown; filtering by installed version; tracking
which releases this device has seen; the auto-open budget; and the modal.

## Where the code lives

```text
lib/features/whats_new/
├── model/ · repository/ · state/
└── ui/
```

## How it works

The remote-content-with-local-gating split, and the consequences of filtering by
installed version and keeping seen-state per device, are documented in the
knowledge bundle:

**→ [knowledge/features/whats_new.md](../../../knowledge/features/whats_new.md)**
