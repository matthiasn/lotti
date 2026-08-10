import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';

/// The user's side of the ad contract (ADR 0055): dismissal, the
/// per-activation rating prompt, and exposure accounting.
///
/// All writes go through the sync service so peers converge; the exposure
/// counters are per-host G-counters incremented under this device's host
/// key, and the rating history is append-only — the concurrent resolver
/// unions it, so nothing recorded here is ever lost to LWW.
class GoalNudgeInteractions {
  GoalNudgeInteractions({
    required this._repository,
    required this._syncService,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;

  /// Per-nudge write queue: every mutation here is a read-modify-write of
  /// the whole row, and the exposure flushes are fire-and-forget — two
  /// overlapping calls would both read the same snapshot and the later
  /// upsert would silently drop the earlier increment (or a dismissal).
  final Map<String, Future<void>> _writeTail = {};

  Future<void> _serialized(String nudgeId, Future<void> Function() write) {
    final tail = (_writeTail[nudgeId] ?? Future<void>.value()).then(
      (_) => write(),
    );
    // The stored tail must never fail, or every later write would rethrow
    // the same error; the caller's future still carries it.
    _writeTail[nudgeId] = tail.catchError((Object _) {});
    return tail;
  }

  /// Whether the rating prompt is due: exactly one outcome per activation
  /// (a skip counts — the prompt never nags twice for the same run).
  static bool ratingDue(GoalNudgeEntity nudge) =>
      nudge.status == GoalNudgeStatus.active &&
      !nudge.ratings.any((r) => r.activation == nudge.activationCount);

  /// Dismisses an active ad — the terminal user verdict (the resolver
  /// keeps it terminal against concurrent writes) and the start of the
  /// same-day quiet window Phase B enforces. [forActivation] is the
  /// activation the user actually SAW: if sync re-ran the nudge while
  /// the close tap was in flight, the write is discarded rather than
  /// silencing a run the user never looked at (the rating path's guard).
  Future<void> dismiss(String nudgeId, {int? forActivation}) =>
      _serialized(nudgeId, () async {
        final nudge = await _repository.getEntity(nudgeId);
        if (nudge is! GoalNudgeEntity) return;
        if (nudge.status != GoalNudgeStatus.active) return;
        if (forActivation != null && forActivation != nudge.activationCount) {
          return;
        }
        final now = clock.now();
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: GoalNudgeStatus.dismissed,
            dismissedAt: now,
            updatedAt: now,
          ),
        );
      });

  /// Records the rating-prompt outcome — [rating] 1..5, or a skip — for
  /// [forActivation] (the activation the user actually SAW; defaults to
  /// the current one). If the persisted activation moved on while the
  /// sheet was open (a synced re-run), the outcome is discarded rather
  /// than mis-attributed to a run the user never looked at. A second
  /// outcome for the same activation is refused silently: the history is
  /// one entry per run, and re-runs re-prompt by incrementing the count.
  Future<void> recordRating(
    String nudgeId, {
    int? rating,
    bool skipped = false,
    int? forActivation,
  }) {
    assert(
      skipped != (rating != null),
      'exactly one of rating/skipped per outcome',
    );
    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError.value(rating, 'rating', 'must be 1..5');
    }
    return _serialized(nudgeId, () async {
      final nudge = await _repository.getEntity(nudgeId);
      if (nudge is! GoalNudgeEntity) return;
      final activation = forActivation ?? nudge.activationCount;
      if (activation != nudge.activationCount) return;
      if (nudge.ratings.any((r) => r.activation == activation)) return;
      await _syncService.upsertEntity(
        nudge.copyWith(
          ratings: [
            ...nudge.ratings,
            GoalNudgeRating(
              activation: activation,
              ratedAt: clock.now(),
              rating: rating,
              skipped: skipped,
            ),
          ],
          updatedAt: clock.now(),
        ),
      );
    });
  }

  /// Accounts one visibility episode: [visibleFor] accumulates into this
  /// host's grow-only counter, one impression is counted, and the
  /// first/last-shown watermarks widen. Called when a banner leaves the
  /// viewport (or the page), not per frame.
  Future<void> recordExposure(
    String nudgeId, {
    required Duration visibleFor,
  }) {
    if (visibleFor <= Duration.zero) return Future.value();
    return _serialized(nudgeId, () async {
      final nudge = await _repository.getEntity(nudgeId);
      if (nudge is! GoalNudgeEntity) return;
      final host = await _syncService.localHost();
      final now = clock.now();
      // The flush arrives at the END of the episode; the banner became
      // visible one episode-length earlier. Stamping `now` would push
      // firstShownAt past a dismissal that raced the disposal flush and
      // corrupt time-to-dismiss metrics.
      final shownAt = now.subtract(visibleFor);
      await _syncService.upsertEntity(
        nudge.copyWith(
          totalVisibleMs: nudge.totalVisibleMs.increment(
            host,
            visibleFor.inMilliseconds,
          ),
          impressionCount: nudge.impressionCount.increment(host),
          firstShownAt: nudge.firstShownAt ?? shownAt,
          lastShownAt: now,
          updatedAt: now,
        ),
      );
    });
  }
}
