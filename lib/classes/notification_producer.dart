/// The narrower seam the LLM tier gets: it may re-word an alert the
/// deterministic tier has armed, and nothing else (ADR 0074). Every
/// [NotificationEpisodeSink] is one, so a producer serves both tiers.
abstract interface class NotificationEpisodeRestater {
  /// Re-words every open, not-yet-fired episode of [subjectId]: [title]
  /// replaces the row's title and [body], when given, its body. Mints
  /// nothing — a subject without an armed episode is left without one — and
  /// leaves an episode that already fired with the words it fired with.
  Future<void> restate(String subjectId, {required String title, String? body});
}

/// The seam between an agent kind's deterministic tier and the synced
/// notification inbox.
///
/// A tier decides *when* a subject deserves an OS-level alert — a person is
/// due, a goal has slipped — and hands that verdict here; what the verdict
/// means for the notification layer is not its concern. Declared in
/// `lib/classes` rather than in the notifications feature so a runtime can
/// depend on the contract without importing the module that fulfils it: the
/// producer implements this and imports the runtime, never the other way
/// round — the direction the relationship reminder established (ADR 0039,
/// amendment 1; ADR 0072).
///
/// [TSubject] is the entity the alert is about. [TDerivation] is the tier's
/// own verdict type, in whatever shape it already has: the producer, not the
/// tier, knows how to read an episode out of it.
///
/// Implementations must be **best-effort and non-throwing**. By the time a
/// sink runs, the wake's real work has committed, and a notification-store
/// hiccup must not fail a wake that succeeded into a retry.
abstract interface class NotificationEpisodeSink<TSubject, TDerivation>
    implements NotificationEpisodeRestater {
  /// Arms the episode [derivation] describes for [subject] and retracts any
  /// episode it supersedes. Called only after the tier's own eligibility gate
  /// has passed.
  Future<void> arm({
    required TSubject subject,
    required TDerivation derivation,
  });

  /// Retracts every open episode for [subjectId] — consent withdrawn, the
  /// subject gone dormant, archived or deleted.
  Future<void> clearFor(String subjectId);
}
