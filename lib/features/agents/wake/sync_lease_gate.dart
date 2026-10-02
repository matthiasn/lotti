import 'dart:async';

/// Whether this device may act on a synced, leased scheduled wake now.
///
/// A lease elects one device per window by letting concurrent claims converge
/// over sync, which only works while the claim is visible to the peers. Two
/// rules follow, both found by TLC in `specs/tla/ProjectWakeGovernor.tla`:
///
/// - **Claim and fire only while connected, with the sync inbox drained.** A
///   claim made offline settles where no peer can see it; a device back from a
///   long absence must apply the backlog — which may hold a peer's consume of
///   the very slot — before it decides anything.
/// - **A claim the connection dropped under proves nothing.** [epoch] counts
///   connection losses; a claim made in an earlier epoch is re-made, which
///   restarts its settle where peers can see it.
///
/// With sync off there are no peers to race, so the gate is always open and
/// the epoch never moves.
class SyncLeaseGate {
  SyncLeaseGate({
    required this._syncEnabled,
    required this._connected,
    required Stream<bool> connectivityChanges,
    required this._waitForInboxDrained,
    this.drainTimeout = const Duration(minutes: 2),
  }) {
    _subscription = connectivityChanges.listen((online) {
      if (_online && !online) _epoch++;
      _online = online;
    });
  }

  final Future<bool> Function() _syncEnabled;
  final bool Function() _connected;
  final Future<void> Function(Duration timeout) _waitForInboxDrained;

  /// How long [ready] waits for the inbox to drain before giving up for now.
  final Duration drainTimeout;

  late final StreamSubscription<bool> _subscription;
  var _online = true;
  var _epoch = 0;

  /// How many times the connection has been lost since start.
  int get epoch => _epoch;

  /// Whether a leased wake may be claimed or fired now: sync is off, or this
  /// device is connected and its inbox drained within [drainTimeout].
  Future<bool> ready() async {
    if (!await _syncEnabled()) return true;
    if (!_online || !_connected()) return false;
    try {
      await _waitForInboxDrained(drainTimeout);
    } on TimeoutException {
      return false;
    }
    return _online && _connected();
  }

  Future<void> dispose() => _subscription.cancel();
}
