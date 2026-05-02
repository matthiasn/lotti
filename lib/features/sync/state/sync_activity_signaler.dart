import 'dart:async';

/// Lightweight pulse emitter for the sidebar's sync activity indicator
/// (variant D4a in `docs/design/`). Emits once per Matrix packet that
/// the local sync engine actually transmitted (TX) or applied (RX) so
/// the UI can flash an LED for ~140 ms per event.
///
/// The signaler is intentionally diagnostic-only: it carries no payload,
/// no ordering guarantees, and is fire-and-forget at the producer side.
/// Listeners use it as a hint to drive ambient UI; correctness lives
/// in the underlying queue/outbox state.
class SyncActivitySignaler {
  SyncActivitySignaler();

  final StreamController<DateTime> _txCtl =
      StreamController<DateTime>.broadcast();
  final StreamController<DateTime> _rxCtl =
      StreamController<DateTime>.broadcast();

  /// Pulses for outbound packets that committed to the homeserver.
  Stream<DateTime> get txPulses => _txCtl.stream;

  /// Pulses for inbound packets that were applied locally.
  Stream<DateTime> get rxPulses => _rxCtl.stream;

  /// Emits a single TX pulse. Used by the outbox path after a single
  /// send or a successful bundle send. The indicator widget coalesces
  /// rapid pulses into a single ~140 ms LED hold (the spec says
  /// "multiple fires within the hold window simply extend it"), so
  /// emitting once per batch is visually identical to emitting once per
  /// committed row — and avoids walking a tight per-item loop on hot
  /// drain paths.
  void pulseTx() {
    if (_txCtl.isClosed) return;
    _txCtl.add(DateTime.now());
  }

  /// Emits one RX pulse. Used by the inbound queue after each
  /// `commitApplied`.
  void pulseRx() {
    if (_rxCtl.isClosed) return;
    _rxCtl.add(DateTime.now());
  }

  Future<void> dispose() async {
    await _txCtl.close();
    await _rxCtl.close();
  }
}
