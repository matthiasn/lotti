import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/services/task_summary_refresh_service.dart';
import 'package:lotti/features/tasks/repository/checklist_events.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_event_listener.g.dart';

/// Listens to checklist events and triggers task summary refreshes.
///
/// This decouples the checklist repository from the AI feature by using
/// an event-driven architecture. The repository emits events, and this
/// listener reacts to them independently.
@Riverpod(keepAlive: true)
class ChecklistEventListener extends _$ChecklistEventListener {
  StreamSubscription<ChecklistEvent>? _subscription;
  final _loggingService = getIt<LoggingService>();

  static const String _callingDomain = 'ChecklistEventListener';

  @override
  void build() {
    final stream = ref.watch(checklistEventsNotifierProvider);
    _subscription = stream.listen(_handleEvent);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
  }

  Future<void> _handleEvent(ChecklistEvent event) async {
    try {
      final service = ref.read(taskSummaryRefreshServiceProvider);

      switch (event) {
        case ChecklistItemCreated(:final checklistId):
          await service.triggerTaskSummaryRefreshForChecklist(
            checklistId: checklistId,
            callingDomain: _callingDomain,
          );

        case ChecklistItemUpdated(:final checklistIds):
          // Trigger refreshes for all affected checklists
          await Future.wait(
            checklistIds.map(
              (id) => service.triggerTaskSummaryRefreshForChecklist(
                checklistId: id,
                callingDomain: _callingDomain,
              ),
            ),
          );

        case ChecklistItemAdded(:final checklistId):
          await service.triggerTaskSummaryRefreshForChecklist(
            checklistId: checklistId,
            callingDomain: _callingDomain,
          );
      }
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: _callingDomain,
        subDomain: '_handleEvent',
        stackTrace: stackTrace,
      );
      // Error is logged but not propagated to avoid disrupting
      // the repository's persistence operations
    }
  }
}

/// Initializes the checklist event listener.
///
/// Call this at app startup to ensure the listener is active:
/// ```dart
/// void main() {
///   // ... other initialization
///   container.read(checklistEventListenerProvider);
/// }
/// ```
void initializeChecklistEventListener(ProviderContainer container) {
  container.read(checklistEventListenerProvider);
}
