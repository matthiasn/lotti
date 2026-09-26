/// Holds the room's applied marker — never the events — while live timeline
/// events have arrived that no seal has covered yet.
///
/// A limited `/sync` response omits the events between the old marker and
/// its slice, and the SDK reports `limited` only in the response's `onSync`,
/// after the slice's events. Holding admission until then (#4502) stranded
/// attachment descriptors; holding only the marker lets every event be
/// queued and applied at once while no commit can move the catch-up anchor
/// past a gap that is not yet claimed. `HoldAnchor` in
/// `specs/tla/InboundQueue.tla`.
///
/// The coordinator counts each arrival synchronously as its listener receives
/// it and seals up to a snapshot once the real sync loop finishes the
/// response. `QueueMarkerAdvancer` consults [isSealed] before advancing. The
/// state is in memory: a restart loses it, and the claim `startImpl` makes
/// covers whatever a previous process had not sealed.
class LiveAnchorHold {
  int _arrived = 0;
  int _sealed = 0;
  int _generation = 0;

  /// Live events received since the last [reset].
  int get arrived => _arrived;

  /// Identifies the current session; a seal snapshot from before a [reset]
  /// must not cover arrivals after it.
  int get generation => _generation;

  /// Whether every arrival is covered by a completed seal.
  bool get isSealed => _sealed >= _arrived;

  /// Records one live timeline event. Called synchronously by the listener,
  /// before any asynchronous handling, so a later seal snapshot covers it.
  void noteArrival() => _arrived++;

  /// Covers the arrivals up to [upTo], a snapshot taken in [generation].
  void seal(int upTo, {required int generation}) {
    if (generation != _generation) return;
    if (upTo > _sealed) _sealed = upTo;
  }

  /// Starts a new session: nothing arrived, nothing held.
  void reset() {
    _generation++;
    _arrived = 0;
    _sealed = 0;
  }
}
