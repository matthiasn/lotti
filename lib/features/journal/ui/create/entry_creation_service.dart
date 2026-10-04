import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/journal/create/create_entry.dart'
    as create_entry;
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_analysis_trigger.dart';
import 'package:lotti/logic/image_import.dart' as image_import;
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:material_ui/material_ui.dart';

/// Service for creating journal entries with dependency injection support.
/// This service wraps the global entry creation functions to make them
/// testable via Riverpod provider overrides.
class EntryCreationService {
  EntryCreationService({this._ref});

  /// Provider container ref captured by [entryCreationServiceProvider].
  /// Optional so the service can still be instantiated bare in
  /// non-Riverpod contexts (e.g. unit tests that target a single
  /// method); methods that need it document the requirement.
  final Ref? _ref;

  /// Creates a text entry and optionally navigates to it.
  /// Returns the created entry or null if creation failed.
  Future<JournalEntity?> createTextEntry({
    String? linkedId,
    String? categoryId,
  }) async {
    final entry = await JournalRepository.createTextEntry(
      const EntryText(plainText: ''),
      linkedId: linkedId,
      categoryId: categoryId,
      started: DateTime.now(),
    );

    if (linkedId == null && entry != null) {
      beamToNamed('/journal/${entry.meta.id}');
    }

    return entry;
  }

  /// Creates a timer entry and starts the timer if linked to a parent entry.
  /// Returns the created timer entry or null if creation failed.
  Future<JournalEntity?> createTimerEntry({JournalEntity? linked}) async {
    final timerItem = await createTextEntry(
      linkedId: linked?.meta.id,
      categoryId: linked?.meta.categoryId,
    );
    if (linked != null) {
      if (timerItem != null) {
        await getIt<TimeService>().start(timerItem, linked);
      }
    }
    return timerItem;
  }

  /// Creates a task linked to [linkedId] and categorized by [categoryId],
  /// hands it the category's default agent, and opens it — the one journey
  /// the Add sheet's task row and the entry action bar share. Returns the
  /// task, or null when creation failed, in which case nothing is opened.
  ///
  /// The agent assignment is fire-and-forget (it logs its own failures) so
  /// the task page opens without waiting on it. Reading the agent service
  /// through this service's own [Ref] rather than a widget's lets a caller
  /// that the navigation unmounts — the entry action bar — await this safely.
  Future<Task?> createTaskAndOpen({
    String? linkedId,
    String? categoryId,
  }) async {
    final task = await create_entry.createTask(
      linkedId: linkedId,
      categoryId: categoryId,
    );
    if (task == null) return null;
    final agentService = _ref?.read(taskAgentServiceProvider);
    if (agentService != null) {
      unawaited(create_entry.autoAssignCategoryAgentWith(agentService, task));
    }
    beamToNamed('/tasks/${task.meta.id}');
    return task;
  }

  /// Shows the audio recording modal.
  void showAudioRecordingModal(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
  }) {
    AudioRecordingModal.show(
      context,
      linkedId: linkedId,
      categoryId: categoryId,
    );
  }

  /// Creates a checklist linked to [task]. Reads
  /// `checklistRepositoryProvider` via the service's own [Ref] so
  /// callers don't have to thread a [WidgetRef] through — and so tests
  /// can stub the service without needing a `WidgetRef` fallback
  /// (`WidgetRef` is sealed in Riverpod 3 and can't be mocked).
  ///
  /// Requires the service to have been constructed with a [Ref] — i.e.
  /// obtained via [entryCreationServiceProvider]. Returns null if not.
  Future<JournalEntity?> createChecklist({required Task task}) async {
    final ref = _ref;
    if (ref == null) return null;
    final result = await ref
        .read(checklistRepositoryProvider)
        .createChecklist(taskId: task.id);
    return result.checklist;
  }

  /// Opens the platform image picker and imports the selected images.
  Future<void> importImage(
    BuildContext context, {
    String? linkedId,
    String? categoryId,
    ImageAnalysisTrigger? analysisTrigger,
  }) {
    return image_import.importImageAssets(
      context,
      linkedId: linkedId,
      categoryId: categoryId,
      analysisTrigger: analysisTrigger,
    );
  }

  /// Opens the "create entry" menu modal — the long-tail items the task
  /// action bar's primary affordances do not expose.
  Future<void> showCreateEntryModal(
    BuildContext context, {
    String? linkedFromId,
    String? categoryId,
  }) {
    return CreateEntryModal.show(
      context: context,
      linkedFromId: linkedFromId,
      categoryId: categoryId,
    );
  }
}

/// Provider for the entry creation service.
/// Can be overridden in tests to mock entry creation behavior.
final entryCreationServiceProvider = Provider<EntryCreationService>((ref) {
  return EntryCreationService(ref: ref);
});
