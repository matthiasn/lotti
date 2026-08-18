/// Deterministic identity inputs for the journal-side goal rows.
///
/// Derivation, not allocation, is the point. The backfill that gives an
/// existing goal agent its journal entry runs on **every device that syncs
/// that agent**, independently and without coordination. Minting random ids
/// would have each device create its own row for the same goal, and sync would
/// faithfully replicate all of them. Seeding the id from something the devices
/// already agree on means they write the *same* row, and last-writer-wins
/// merges it instead of duplicating it.
///
/// These return the **input string** for
/// `PersistenceLogic.createMetadata(uuidV5Input:)`, which is the repository's
/// existing deduplication mechanism (`MetadataService.generateId` hashes it
/// into a UUID v5). Deliberately not a second id scheme of its own — the
/// prefixes below are what keep the two families from colliding.
library;

/// Identity input for the goal coached by [agentId].
///
/// The agent id is the one identifier every device shares for a goal before
/// the journal entry exists, which is what makes it the correct seed.
String goalEntryUuidV5Input(String agentId) => 'goal:$agentId';

/// Identity input for the immutable snapshot of one spec version.
///
/// Seeded with the agent-side `goalSpecVersion` id (`<agentId>:spec-v<n>`),
/// which is already unique and immutable, so re-running the backfill
/// re-derives the same snapshot rather than appending a duplicate of a version
/// that has not changed.
String goalSpecSnapshotUuidV5Input(String specVersionId) =>
    'goal-spec:$specVersionId';
