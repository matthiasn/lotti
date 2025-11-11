import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/file_utils.dart';

/// Service for creating journal entries with dependency injection support.
/// This service wraps the global entry creation functions to make them
/// testable via Riverpod provider overrides.
class EntryCreationService {
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
    final timerItem = await createTextEntry(linkedId: linked?.meta.id);
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
}

/// Provider for the entry creation service.
/// Can be overridden in tests to mock entry creation behavior.
final entryCreationServiceProvider = Provider<EntryCreationService>((ref) {
  return EntryCreationService();
});
