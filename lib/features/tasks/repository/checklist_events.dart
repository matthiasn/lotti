import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_events.g.dart';

/// Events emitted by the checklist repository for cross-feature communication.
///
/// This allows other features (like AI task summaries) to react to checklist
/// changes without creating tight coupling in the repository layer.
sealed class ChecklistEvent {
  const ChecklistEvent();
}

/// Emitted when a checklist item is created.
class ChecklistItemCreated extends ChecklistEvent {
  const ChecklistItemCreated({required this.checklistId});
  final String checklistId;
}

/// Emitted when a checklist item is updated.
class ChecklistItemUpdated extends ChecklistEvent {
  const ChecklistItemUpdated({required this.checklistIds});
  final Set<String> checklistIds;
}

/// Emitted when an item is added to a checklist.
class ChecklistItemAdded extends ChecklistEvent {
  const ChecklistItemAdded({required this.checklistId});
  final String checklistId;
}

/// Provider for the checklist event stream.
///
/// Other features can watch this stream to react to checklist changes:
/// ```dart
/// ref.listen(checklistEventsProvider, (previous, next) {
///   switch (next) {
///     case ChecklistItemCreated(:final checklistId):
///       triggerRefresh(checklistId);
///     case ChecklistItemUpdated(:final checklistIds):
///       for (final id in checklistIds) triggerRefresh(id);
///     case ChecklistItemAdded(:final checklistId):
///       triggerRefresh(checklistId);
///   }
/// });
/// ```
@Riverpod(keepAlive: true)
class ChecklistEventsNotifier extends _$ChecklistEventsNotifier {
  final _controller = StreamController<ChecklistEvent>.broadcast();

  @override
  Stream<ChecklistEvent> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  /// Emits a checklist event to all listeners.
  void emit(ChecklistEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
}
