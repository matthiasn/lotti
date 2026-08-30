import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/goals/service/goal_checkin_notifier.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';

import '../../../mocks/mocks.dart';

void main() {
  tearDown(getIt.reset);

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(MockAgentRepository()),
        agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
        agentServiceProvider.overrideWithValue(MockAgentService()),
        cloudInferenceRepositoryProvider.overrideWithValue(
          MockCloudInferenceRepository(),
        ),
        loggingServiceProvider.overrideWithValue(MockLoggingService()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void registerJournalStack() {
    getIt
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
      ..registerSingleton<MetadataService>(MockMetadataService())
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications());
  }

  group('without the journal stack', () {
    test('the journal-side providers resolve to null, not to a throw', () {
      final c = container();

      // The agent tier is authoritative for evaluation and must not acquire a
      // hard dependency on journal infrastructure: a missing stack means no
      // mirror, not a broken goal runtime.
      expect(c.read(goalRepositoryProvider), isNull);
      expect(c.read(goalMirrorServiceProvider), isNull);
      expect(c.read(goalCheckInNotifierProvider), isNull);
      expect(c.read(goalCheckInSourceReaderProvider), isNull);
      expect(c.read(goalCriterionNameReaderProvider), isNull);
    });
  });

  group('with the journal stack registered', () {
    setUp(registerJournalStack);

    test('the repository and the services it feeds are constructed', () {
      final c = container();

      expect(c.read(goalRepositoryProvider), isNotNull);
      expect(c.read(goalMirrorServiceProvider), isNotNull);
      expect(c.read(goalCheckInNotifierProvider), isA<GoalCheckInNotifier>());
      expect(c.read(goalCheckInSourceReaderProvider), isNotNull);
      expect(c.read(goalCriterionNameReaderProvider), isNotNull);
    });

    test('the compactor is available wherever inference is', () {
      expect(container().read(goalCheckInCompactorProvider), isNotNull);
    });
  });
}
