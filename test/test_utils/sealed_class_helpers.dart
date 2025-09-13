import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:uuid/uuid.dart';

/// Helper functions to create test instances of sealed classes
/// for use in tests that require fallback values for mocktail.

const _uuid = Uuid();

/// Creates a fake JournalEntity for testing
JournalEntity createFakeJournalEntity({String? id}) {
  final now = DateTime.now();
  return JournalEntry(
    meta: Metadata(
      id: id ?? _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      starred: false,
      private: false,
    ),
    entryText: const EntryText(
      plainText: 'Test entry',
    ),
  );
}

/// Creates a fake TagEntity for testing
TagEntity createFakeTagEntity() {
  final now = DateTime.now();
  return TagEntity.genericTag(
    id: _uuid.v4(),
    createdAt: now,
    updatedAt: now,
    vectorClock: null,
    tag: 'test',
    private: false,
    inactive: false,
  );
}

/// Creates a fake SyncMessage for testing
SyncMessage createFakeSyncMessage() {
  return SyncMessage.journalEntity(
    id: _uuid.v4(),
    jsonPath: 'test/path',
    vectorClock: null,
    status: SyncEntryStatus.initial,
  );
}

/// Creates a fake AiConfig for testing
AiConfig createFakeAiConfig() {
  final now = DateTime.now();
  return AiConfig.prompt(
    id: _uuid.v4(),
    name: 'Test AI Config',
    systemMessage: 'Test system message',
    userMessage: 'Test user message',
    defaultModelId: 'test-model-id',
    modelIds: ['test-model-id'],
    createdAt: now,
    useReasoning: false,
    requiredInputData: [],
    aiResponseType: AiResponseType.taskSummary,
  );
}

// Register these functions as factory methods for testing
// ignore: non_constant_identifier_names
JournalEntity FakeJournalEntity() => createFakeJournalEntity();
// ignore: non_constant_identifier_names
TagEntity FakeTagEntity() => createFakeTagEntity();
// ignore: non_constant_identifier_names
SyncMessage FakeSyncMessage() => createFakeSyncMessage();
// ignore: non_constant_identifier_names
AiConfig FakeAiConfig() => createFakeAiConfig();

// Helper function to create JournalEntity with specific ID
// ignore: non_constant_identifier_names
JournalEntity MockJournalEntity(String id) => createFakeJournalEntity(id: id);
