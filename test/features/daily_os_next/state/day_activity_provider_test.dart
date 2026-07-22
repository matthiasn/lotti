import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  late Directory root;
  late DayProcessingOutboxRepository outbox;
  late MockJournalDb journalDb;

  const dayId = 'dayplan-2026-07-18';
  final date = DateTime(2026, 7, 18);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-activity-provider-test-');
    outbox = DayProcessingOutboxRepository(rootDirectory: root);
    final mocks = await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<Directory>(root),
    );
    journalDb = mocks.journalDb;
    when(
      () => journalDb.getDayAudioEntries(dayId),
    ).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await outbox.dispose();
    await tearDownTestGetIt();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer(MockAgentRepository repository) {
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
    return container;
  }

  test(
    'loads an offline day projection from its resolved dependencies',
    () async {
      final repository = MockAgentRepository();
      when(
        () => repository.getEntitiesByIds(any()),
      ).thenAnswer((_) async => const {});

      final container = makeContainer(repository);

      expect(await container.read(dayActivityProvider(date).future), isEmpty);
      // The summary resolves by its deterministic day-keyed id (ADR 0032):
      // the writing agent varies across the cutover, the id does not.
      verify(
        () => repository.getEntitiesByIds([dayAgentSummaryEntityId(dayId)]),
      ).called(1);
      verify(() => journalDb.getDayAudioEntries(dayId)).called(1);
    },
  );

  test(
    'surfaces a summary written by the per-day agent',
    () async {
      final repository = MockAgentRepository();
      final summary = makeTestDaySummary(
        dayId: dayId,
        agentId: perDayAgentId(dayId),
        text: 'wrapped the day',
      );
      when(
        () => repository.getEntitiesByIds(any()),
      ).thenAnswer((_) async => {summary.id: summary});

      final container = makeContainer(repository);

      final entries = await container.read(dayActivityProvider(date).future);
      expect(entries, hasLength(1));
      expect(entries.single.kind, DayActivityEntryKind.summary);
      expect(entries.single.summary!.text, 'wrapped the day');
    },
  );

  test(
    'ignores a summary row owned by a foreign agent',
    () async {
      final repository = MockAgentRepository();
      final summary = makeTestDaySummary(
        dayId: dayId,
        agentId: 'someone-else',
      );
      when(
        () => repository.getEntitiesByIds(any()),
      ).thenAnswer((_) async => {summary.id: summary});

      final container = makeContainer(repository);

      expect(await container.read(dayActivityProvider(date).future), isEmpty);
    },
  );
}
