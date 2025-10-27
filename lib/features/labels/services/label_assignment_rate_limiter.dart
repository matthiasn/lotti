import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

/// In-memory rate limiter for AI label assignment.
///
/// Notes and limitations:
/// - Memory-based: state is lost on app restart (window resets).
/// - Per-task window: blocks repeated assignments to the same task
///   within [rateLimitWindow].
/// - Not persisted: suitable for UX throttling, not security.
class LabelAssignmentRateLimiter {
  LabelAssignmentRateLimiter({Clock? clock}) : _clock = clock ?? const Clock();

  final Clock _clock;
  final Map<String, DateTime> _lastAssignment = {};

  static const Duration rateLimitWindow = Duration(minutes: 5);

  bool isRateLimited(String taskId) {
    final now = _clock.now();
    _prune(now);
    final last = _lastAssignment[taskId];
    return last != null && now.difference(last) < rateLimitWindow;
  }

  void recordAssignment(String taskId) {
    final now = _clock.now();
    _prune(now);
    _lastAssignment[taskId] = now;
  }

  DateTime? nextAllowedAt(String taskId) {
    final now = _clock.now();
    _prune(now);
    final last = _lastAssignment[taskId];
    if (last == null) return null;
    final remaining = rateLimitWindow - now.difference(last);
    return remaining.isNegative ? null : last.add(rateLimitWindow);
  }

  void _prune(DateTime now) {
    _lastAssignment.removeWhere(
      (_, ts) => now.difference(ts) >= rateLimitWindow,
    );
  }

  void clearHistory() => _lastAssignment.clear();

  @visibleForTesting
  Map<String, DateTime> get history => Map.unmodifiable(_lastAssignment);

  @visibleForTesting
  void setLastAssignmentForTesting(String taskId, DateTime time) {
    _lastAssignment[taskId] = time;
  }
}
