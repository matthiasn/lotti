import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_message.dart';

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
