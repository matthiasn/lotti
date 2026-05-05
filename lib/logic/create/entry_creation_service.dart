import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart' as image_import;
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/file_utils.dart';

/// Service for creating journal entries with dependency injection support.
/// This service wraps the global entry creation functions to make them
/// testable via Riverpod provider overrides.
class EntryCreationService {
  EntryCreationService({Ref? ref}) : _ref = ref;

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
      id: uuid.v1(),
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
    AutomaticImageAnalysisTrigger? analysisTrigger,
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
