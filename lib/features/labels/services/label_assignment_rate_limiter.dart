import 'package:meta/meta.dart';

/// In-memory rate limiter for AI label assignment.
///
/// Notes and limitations:
/// - Memory-based: state is lost on app restart (window resets).
/// - Per-task window: blocks repeated assignments to the same task
///   within [rateLimitWindow].
/// - Not persisted: suitable for UX throttling, not security.
class LabelAssignmentRateLimiter {
  final Map<String, DateTime> _lastAssignment = {};

  static const Duration rateLimitWindow = Duration(minutes: 5);

  bool isRateLimited(String taskId) {
    final last = _lastAssignment[taskId];
    return last != null && DateTime.now().difference(last) < rateLimitWindow;
  }

  void recordAssignment(String taskId) {
    _lastAssignment[taskId] = DateTime.now();
  }

  void clearHistory() => _lastAssignment.clear();

  @visibleForTesting
  Map<String, DateTime> get history => Map.unmodifiable(_lastAssignment);

  @visibleForTesting
  void setLastAssignmentForTesting(String taskId, DateTime time) {
    _lastAssignment[taskId] = time;
  }
}
