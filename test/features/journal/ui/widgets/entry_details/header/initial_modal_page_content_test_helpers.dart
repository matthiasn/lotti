import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';

// File-local on purpose: riverpod controller doubles override `build` with
// test-specific state and cannot be expressed as centralized mocktail mocks
// (the provider instantiates the notifier itself, and mocked notifiers are
// rejected by riverpod's lifecycle assertions).
class TestEntryController extends EntryController {
  TestEntryController(this._entry);

  final JournalEntity? _entry;

  @override
  Future<EntryState?> build() async {
    final entry = _entry;
    if (entry == null) return null;
    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

JournalEntity textEntry({List<String>? labelIds}) {
  final now = DateTime(2023);
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: 'entry-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
  );
}

JournalEntity taskEntry({List<String>? labelIds, String? languageCode}) {
  final now = DateTime(2023);
  return JournalEntity.task(
    meta: Metadata(
      id: 'task-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: [],
      title: 'Test Task',
      languageCode: languageCode,
    ),
  );
}
