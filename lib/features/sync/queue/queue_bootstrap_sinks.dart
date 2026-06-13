import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:matrix/matrix.dart';

/// Outcome of a single forward- or backward-walk bootstrap pass.
/// Distinguishes "walk ran but produced no pages because the server
/// couldn't resolve the anchor" from "walk ran partially but threw
/// mid-way" so the coordinator can decide whether to fall back.
enum BootstrapOutcome {
  completed,
  incomplete,
  errorNoProgress,
}

/// [BootstrapSink] decorator that forwards each accepted page to an
/// observational [onProgress] callback before delegating to [inner].
///
/// A throw from [onProgress] (e.g. `setState` on an unmounted widget) is
/// swallowed so it cannot abort `collectHistoryForBootstrap` mid-walk and
/// leave the queue partially filled.
class ProgressForwardingSink implements BootstrapSink {
  ProgressForwardingSink({
    required this.inner,
    this.onProgress,
  });

  final BootstrapSink inner;
  final void Function(BootstrapPageInfo info)? onProgress;

  @override
  int? get lastAcceptedCount => inner.lastAcceptedCount;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    // `onProgress` is purely observational (UI progress dot, log line).
    // A throw from the callback — e.g. `setState` on an unmounted
    // widget — must not abort `collectHistoryForBootstrap` mid-walk
    // and leave the queue partially filled. Swallow-and-continue.
    try {
      onProgress?.call(info);
    } catch (_) {
      // Intentionally empty: progress is diagnostic, not load-bearing.
    }
    return inner.onPage(events, info);
  }
}

/// Accumulates the inner sink's `lastAcceptedCount` across every page
/// so the coordinator can tell whether a bridge pass accepted zero
/// events overall — the precise signal that a reconnect catch-up
/// wedged on a stale SDK cache and the gap-recovery unbounded walk
/// needs to fire on the next live gap. Pure pass-through otherwise.
class TotalAcceptedCountingSink implements BootstrapSink {
  TotalAcceptedCountingSink(this._inner);

  final BootstrapSink _inner;
  int totalAccepted = 0;

  @override
  int? get lastAcceptedCount => _inner.lastAcceptedCount;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    final shouldContinue = await _inner.onPage(events, info);
    final accepted = _inner.lastAcceptedCount;
    if (accepted != null) totalAccepted += accepted;
    return shouldContinue;
  }
}
