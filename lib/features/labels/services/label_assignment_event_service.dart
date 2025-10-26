import 'dart:async';

class LabelAssignmentEvent {
  LabelAssignmentEvent({
    required this.taskId,
    required this.assignedIds,
    this.source = 'ai',
  });

  final String taskId;
  final List<String> assignedIds;
  final String source; // e.g., 'ai' or 'user'
}

class LabelAssignmentEventService {
  final StreamController<LabelAssignmentEvent> _controller =
      StreamController<LabelAssignmentEvent>.broadcast();

  Stream<LabelAssignmentEvent> get stream => _controller.stream;

  void publish(LabelAssignmentEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
