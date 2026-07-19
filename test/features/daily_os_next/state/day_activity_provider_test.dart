import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late Directory root;
  late DayProcessingOutboxRepository outbox;
  late MockJournalDb journalDb;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-activity-provider-test-');
    outbox = DayProcessingOutboxRepository(rootDirectory: root);
    final mocks = await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<Directory>(root),
    );
    journalDb = mocks.journalDb;
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalAudio'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: const [1, 0],
        ids: null,
        limit: 64,
      ),
    ).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await outbox.dispose();
    await tearDownTestGetIt();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'loads an offline day projection from its resolved dependencies',
    () async {
      final repository = MockAgentRepository();
      when(
        () => repository.getEntitiesByAgentId(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.daySummary,
        ),
      ).thenAnswer((_) async => const []);
      final date = DateTime(2026, 7, 18);
      final container = ProviderContainer(
        overrides: [
          dayProcessingOutboxRepositoryProvider.overrideWithValue(outbox),
          capturesForDateProvider.overrideWith((ref, date) async => const []),
          draftedPlanForDateProvider.overrideWith((ref, date) async => null),
          agentRepositoryProvider.overrideWithValue(repository),
          agentUpdateStreamProvider.overrideWith(
            (ref, agentId) => const Stream<Set<String>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(dayActivityProvider(date).future), isEmpty);
      verify(
        () => repository.getEntitiesByAgentId(
          dailyOsPlannerAgentId,
          type: AgentEntityTypes.daySummary,
        ),
      ).called(1);
    },
  );
}
