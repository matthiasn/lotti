import 'package:uuid/uuid.dart';

/// Namespace every demo id is derived under. Fixed forever: it is what makes
/// [demoUuid] deterministic across machines, runs and app versions, so the
/// ids a demo world's seed manifest recorded still resolve after a reseed.
const _demoIdNamespace = '5f40db97-f501-490a-b2a4-5ec7325fc1c2';

/// The UUID a demo entity is persisted under, derived from its readable
/// [slug].
///
/// Seeded entities live in a real world and must be indistinguishable from
/// anything the user made there — and everywhere else in the app a journal
/// entity's id is a UUID. Two mechanisms depend on that shape:
///
/// * the route locations gate their detail page on `isUuid`
///   (`TasksLocation`, `JournalLocation`, `EventsLocation`,
///   `DashboardsLocation`), so a non-UUID id opens nothing at all — on
///   desktop the detail pane is cleared, on mobile no page is pushed, and
///   either way the tap looks like it never happened;
/// * `getIdFromSavedRoute` extracts the linked id from the persisted route
///   with a UUID regex, which is how the global create-entry commands know
///   what to link to.
///
/// Deriving rather than hard-coding keeps the world file readable — a call
/// still reads `demoUuid('task-air-scrubbers')` — while what reaches the
/// database is a real v5 UUID.
String demoUuid(String slug) => const Uuid().v5(_demoIdNamespace, slug);
