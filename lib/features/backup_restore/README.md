# Backup and restore

Backup and restore owns Lotti's independent recovery artifact. Sync keeps
devices converged, but it can also propagate deletion or damaged state; it is
therefore not a backup.

The feature is being built in layers. The current module establishes the
storage contract and can publish a verified snapshot from an already-quiesced
profile. Encryption, restore, and settings flows build on that boundary. It
does not yet expose a user-facing backup action.

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
│   └── profile_backup_manifest.dart  versioned stores, files, sizes, hashes
├── service/
│   └── quiesced_profile_snapshot_service.dart
│                                       verified staging and atomic publish
└── README.md
```

The catalog is deliberately conservative: known caches and diagnostics are
omitted, unsafe transaction artifacts abort capture, and unknown profile files
are included by default. That last rule makes storage additions fail toward a
larger encrypted backup instead of silent data loss.

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

Lifecycle quiescence, portable packaging, key handling, restore activation,
retention, progress UI, and automated restore drills are follow-on layers built
against the catalog, manifest, and staging contract.

The store classifications, manifest invariants, privacy boundary, and planned
capture lifecycle are documented in the knowledge bundle:

**→ [knowledge/features/backup-and-restore.md](../../../knowledge/features/backup-and-restore.md)**
