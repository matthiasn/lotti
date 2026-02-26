import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  group('templateWakeRunTimeSeriesProvider', () {
    late MockAgentRepository mockRepository;

    setUp(() {
      mockRepository = MockAgentRepository();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    }

    test('returns computed time series from repository data', () async {
      final day1 = DateTime(2024, 3, 15);
      final day2 = DateTime(2024, 3, 16);

      when(() => mockRepository.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => [
                makeTestWakeRun(
                  runKey: 'r1',
                  status: 'completed',
                  createdAt: day1,
                  templateId: kTestTemplateId,
                  templateVersionId: 'v1',
                  startedAt: day1,
                  completedAt: day1.add(const Duration(seconds: 10)),
                ),
                makeTestWakeRun(
                  runKey: 'r2',
                  status: 'failed',
                  createdAt: day2,
                  templateId: kTestTemplateId,
                  templateVersionId: 'v1',
                  startedAt: day2,
                  completedAt: day2.add(const Duration(seconds: 5)),
                ),
              ]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateWakeRunTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, hasLength(2));
      expect(result.dailyBuckets[0].successCount, 1);
      expect(result.dailyBuckets[1].failureCount, 1);
      expect(result.versionBuckets, hasLength(1));
      expect(result.versionBuckets.first.totalRuns, 2);
    });

    test('returns empty time series when no runs exist', () async {
      when(() => mockRepository.getWakeRunsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => []);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        templateWakeRunTimeSeriesProvider(kTestTemplateId).future,
      );

      expect(result.dailyBuckets, isEmpty);
      expect(result.versionBuckets, isEmpty);
    });
  });
}
