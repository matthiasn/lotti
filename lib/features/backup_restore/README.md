# Backup and restore

Backup and restore owns Lotti's independent recovery artifact. Sync keeps
devices converged, but it can also propagate deletion or damaged state; it is
therefore not a backup.

The feature is being built in layers. The current module establishes the
storage contract, can capture the running profile by closing it strictly and
starting it again, can turn that capture into a passphrase-encrypted portable
file, and can restore such a file over the running profile with a journaled
rollback. It does not yet expose a user-facing backup or restore action.

## What it will do for the user

- Capture one complete active profile, including its authoritative databases,
  media, and file-backed payloads.
- Protect credentials and private content inside an authenticated encrypted
  bundle.
- Verify content before publishing a backup and again before changing a
  profile during restore.
- Restore through an isolated staging world, preserving the current world for
  rollback until the restored one boots successfully.
- Explain incompatible, corrupt, or incomplete backups without leaving the
  user's profile half-replaced.

## What this module owns now

```text
lib/features/backup_restore/
├── domain/
│   ├── profile_backup_catalog.dart   profile-root inventory and path policy
│   ├── profile_backup_manifest.dart  versioned stores, files, sizes, hashes
│   └── profile_backup_bundle_header.dart
│                                       unencrypted header and key slots
├── service/
│   ├── quiesced_profile_snapshot_service.dart
│   │                                   verified staging and atomic publish
│   ├── profile_backup_coordinator.dart
│   │                                   strict close, capture, restart
│   ├── profile_backup_bundle_codec.dart
│   │                                   encrypt, verify, publish; decrypt
│   ├── profile_backup_bundle_store.dart
│   │                                   naming, retention, leftover cleanup
│   ├── closed_sqlite_file.dart         integrity check of a closed database
│   ├── profile_restore_preflight.dart  decrypt beside the profile and check
│   ├── profile_root_swap.dart          journaled swap, rollback, recovery
│   └── profile_restore_coordinator.dart
│                                       preflight, swap, verify, commit
└── README.md
```

The catalog is deliberately conservative: known caches, diagnostics, and
superseded migration stores are omitted, unsafe transaction artifacts abort
capture, and unknown profile files are included by default. That last rule
makes storage additions fail toward a larger encrypted backup instead of
silent data loss.

The staging service scans one closed profile root, rejects journal companions
and symbolic links, copies included bytes into a private partial directory,
rehashes the source, runs SQLite integrity checks, verifies the staged payload
against its manifest, and only then renames the directory into place. Any
failure removes the partial stage and leaves an existing published snapshot
untouched.

## What it delegates

Profile lifecycle code remains responsible for identifying and restarting the
active world. Each database remains responsible for its own schema and
migrations. The Matrix SDK and ObjectBox remain responsible for closing their
stores. This feature coordinates those owners and refuses to snapshot when
strict quiescence cannot be proven.

The coordinator refuses to copy anything unless every service and database
of the running profile closed cleanly, and then starts the same profile
again; if even that fails, a relaunch boots the unchanged profile. A bundle is encrypted under the user's passphrase, which is never stored:
it opens on any device that knows it, and a forgotten passphrase cannot be
recovered. API keys stay in the device keystore and are not part of a backup.
A restore replaces the running profile only after the backup has been
decrypted and checked beside it, and keeps the original until the restored
profile has started and opened its databases; a failure, or a crash at any
point, puts the original back. Progress UI and automated restore drills are
follow-on layers.

The store classifications, manifest invariants, privacy boundary, and planned
capture lifecycle are documented in the knowledge bundle:

**→ [knowledge/features/backup-and-restore.md](../../../knowledge/features/backup-and-restore.md)**
