import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

// Real fallback values for sealed unions used with mocktail

final JournalEntity fallbackJournalEntity = testTextEntry;

final TagEntity fallbackTagEntity = testTag1;

const SyncMessage fallbackSyncMessage = SyncJournalEntity(
  id: 'fallback-id',
  jsonPath: '/tmp/fallback.json',
  vectorClock: null,
  status: SyncEntryStatus.initial,
);

final AiConfig fallbackAiConfig = AiConfig.inferenceProvider(
  id: 'config-id',
  baseUrl: 'http://example.com',
  apiKey: 'key',
  name: 'name',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  inferenceProviderType: InferenceProviderType.openAi,
);

/// Registers all commonly used fallback values for mocktail in one call.
///
/// Call this in `setUpAll()` or `setUp()` instead of scattering individual
/// `registerFallbackValue()` calls across test files. Safe to call multiple
/// times — mocktail deduplicates internally.
void registerAllFallbackValues() {
  // Sealed union / abstract class fallbacks (need real instances)
  registerFallbackValue(fallbackJournalEntity);
  registerFallbackValue(fallbackTagEntity);
  registerFallbackValue(fallbackSyncMessage);
  registerFallbackValue(fallbackAiConfig);

  // Fake classes from mocks.dart
  registerFallbackValue(FakeMetadata());
  registerFallbackValue(FakeDashboardDefinition());
  registerFallbackValue(FakeHabitDefinition());
  registerFallbackValue(FakeCategoryDefinition());
  registerFallbackValue(FakeEntryText());
  registerFallbackValue(FakeTaskData());
  registerFallbackValue(FakeJournalAudio());
  registerFallbackValue(FakeMeasurementData());
  registerFallbackValue(FakeHabitCompletionData());
  registerFallbackValue(FakeAiConfigPrompt());
  registerFallbackValue(FakeAiConfigModel());
  registerFallbackValue(FakeAiConfigInferenceProvider());
  registerFallbackValue(FakeChatSession());
  registerFallbackValue(FakeChecklistItemData());

  // Common builtin fallbacks
  registerFallbackValue(StackTrace.empty);
  registerFallbackValue(Duration.zero);
  registerFallbackValue(Uri());
}
