# Sync

Single-user, multi-device replication over end-to-end encrypted Matrix.

* [Overview](overview.md) - what the feature owns, how it is wired, and the code map.
* [Message model](message-model.md) - the twenty SyncMessage families and which seven are sequence-tracked.
* [Vector clocks and conflict resolution](vector-clocks-and-conflicts.md) - causal ordering, supersession, and what the user sees when devices diverge.
* [Send path](send-path.md) - outbox staging, the CAS claim, dequeue-time bundling, retries.
* [Receive path](receive-path.md) - the inbound queue pipeline, anchored catch-up, monotonic markers.
* [Sequence log and backfill](sequence-and-backfill.md) - causal accounting and gap repair.
* [Node profiles and synced-audio auto-trigger](node-profiles-and-auto-trigger.md) - capability advertisement and local-only inference.

# Related

* [Persistence](../../architecture/persistence.md) - `sync.sqlite` and the change-notification streams.
* [Security and privacy](../../architecture/security-and-privacy.md) - the encryption story.
* [Agents](../agents/) - the largest producer of sync traffic after the journal.
