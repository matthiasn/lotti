import 'dart:async';
import 'package:meta/meta.dart';

/// Notification that labels were assigned to a task.
///
/// Emitted by [LabelAssignmentEventService] after a successful persist so UI
/// can react (e.g. show a toast with undo). [source] distinguishes an agent
/// assignment (`'ai'`) from a manual one (`'user'`).
@immutable
class LabelAssignmentEvent {
  const LabelAssignmentEvent({
    required this.taskId,
    required this.assignedIds,
    this.source = 'ai',
  });

  final String taskId;
  final List<String> assignedIds;
  final String source; // e.g., 'ai' or 'user'
}

/// Broadcast event bus for label-assignment notifications.
///
/// The label assignment processor [publish]es a [LabelAssignmentEvent] after
/// persisting; widgets subscribe to [stream] to render assignment feedback.
/// Decouples the write path from the UI so the processor has no widget
/// dependency. Publishing after [dispose] is a safe no-op.
class LabelAssignmentEventService {
  final StreamController<LabelAssignmentEvent> _controller =
      StreamController<LabelAssignmentEvent>.broadcast();

  /// Broadcast stream of assignment events; multiple listeners are supported.
  Stream<LabelAssignmentEvent> get stream => _controller.stream;

  /// Emits [event] to subscribers, ignoring the call if the bus is disposed.
  void publish(LabelAssignmentEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  /// Closes the underlying broadcast controller; subsequent [publish] calls
  /// become no-ops.
  Future<void> dispose() async {
    await _controller.close();
  }
}
