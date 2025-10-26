class LabelAssignmentRateLimiter {
  final Map<String, DateTime> _lastAssignment = {};

  bool isRateLimited(
    String taskId, {
    Duration window = const Duration(minutes: 5),
  }) {
    final last = _lastAssignment[taskId];
    return last != null && DateTime.now().difference(last) < window;
  }

  void recordAssignment(String taskId) {
    _lastAssignment[taskId] = DateTime.now();
  }
}
