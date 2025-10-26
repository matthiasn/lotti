import 'package:meta/meta.dart';

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
